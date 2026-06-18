import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:feature_auth/feature_auth.dart';
import 'package:feature_circle/feature_circle.dart';
import 'package:feature_discover/feature_discover.dart' hide dioProvider;
import 'package:feature_inbox/feature_inbox.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_platform/raver_platform.dart';
import 'package:raver_models/raver_models.dart';
import 'package:ravehub/di/app_providers.dart';
import 'package:ravehub/push/push_router.dart';
import 'package:ravehub/router/deep_link_handler.dart';
import 'package:ravehub/router/share_link_resolver.dart';

/// Performs one-time app initialisation on startup.
///
/// Called from `main()` after [WidgetsFlutterBinding.ensureInitialized] and
/// before [runApp]. The steps mirror the iOS `AppBootstrapper`:
///
///  1. Restore the persisted session from secure storage.
///  2. Restore language and appearance preferences from SharedPreferences.
///  3. Load and register an existing push token if notifications are already
///     authorized.
///
/// All steps are best-effort: failures are logged but do not prevent the app
/// from launching.
class AppBootstrap {
  const AppBootstrap._();

  /// Cached push token for deferred registration (e.g. after login).
  static String? _cachedPushToken;

  /// Runs the full bootstrap sequence.
  static Future<void> run(ProviderContainer container) async {
    _configureFeatureServices(container);

    await Future.wait([
      _restoreSession(container),
      _restorePreferences(container),
    ]);

    await syncUnreadCountsIfNeeded(container);

    await _loadPushTokenIfAuthorized(container);
  }

  // ---- Service wiring -----------------------------------------------------

  static void _configureFeatureServices(ProviderContainer container) {
    final dio = container.read(dioProvider);
    final tokenStore = container.read(sessionTokenStoreProvider);
    final appState = container.read(appStateProvider.notifier);

    AuthServiceLocator.instance.initialize(
      dio: dio,
      tokenStore: tokenStore,
      registrationLocationSaver: (location) async {
        try {
          await ProfileServiceLocator.profileRepository.updateLocation(
            location: location,
          );
          developer.log(
            'Registration home-city location saved.',
            name: 'Bootstrap',
          );
        } catch (error, stackTrace) {
          developer.log(
            'Registration home-city location save failed: $error',
            name: 'Bootstrap',
            level: 900,
            stackTrace: stackTrace,
          );
        }
      },
      authenticatedSessionHandler: (payload) async {
        appState.setSession(_sessionFromAuthPayload(payload));
        await syncUnreadCountsIfNeeded(container);
        await registerPushTokenIfNeeded(container);
      },
    );
    DiscoverServiceLocator.configureDio(dio);
    DiscoverServiceLocator.configureCurrentUserIdProvider(
      () => appState.session?.user.id,
    );
    CircleServiceLocator.configureDio(dio);
    CircleServiceLocator.configureCurrentUserIdProvider(
      () => appState.session?.user.id,
    );
    InboxServiceLocator.configureDio(dio);
    InboxServiceLocator.configureUnreadCountSync(
      (counts) {
        appState.updateUnreadCounts(
          community: counts.community,
          events: counts.followedEvents,
          djs: counts.followedDJs,
          brands: counts.followedBrands,
        );
        unawaited(_syncSystemBadgeFromCounts(counts));
      },
    );
    ProfileServiceLocator.configureDio(
      dio,
      tokenStore: tokenStore,
      onAccountSessionCleared: appState.clearSession,
    );

    developer.log('Feature services configured with live Dio.',
        name: 'Bootstrap');
  }

  // ---- Session restoration ------------------------------------------------

  static Future<void> _restoreSession(ProviderContainer container) async {
    try {
      final appState = container.read(appStateProvider.notifier);
      final restored = await appState.restoreSession();
      developer.log(
        'Session restore: ${restored ? "success" : "no stored session"}',
        name: 'Bootstrap',
      );
    } catch (e) {
      developer.log(
        'Session restore failed: $e',
        name: 'Bootstrap',
        level: 900,
      );
    }
  }

  // ---- Preferences --------------------------------------------------------

  static Future<void> _restorePreferences(
    ProviderContainer container,
  ) async {
    try {
      final appState = container.read(appStateProvider.notifier);
      await Future.wait([
        appState.restoreLanguagePreference(),
        appState.restoreAppearancePreference(),
      ]);
      developer.log('Preferences restored.', name: 'Bootstrap');
    } catch (e) {
      developer.log(
        'Preference restore failed: $e',
        name: 'Bootstrap',
        level: 900,
      );
    }
  }

  // ---- Push notifications -------------------------------------------------

  static Future<void> _loadPushTokenIfAuthorized(
    ProviderContainer container,
  ) async {
    try {
      final token = await PushNotificationService.instance.getPushToken();
      _cachedPushToken = token;

      developer.log(
        'Push token: ${token ?? "unavailable"}',
        name: 'Bootstrap',
      );

      // If we already have an active session, register the token immediately.
      if (token != null) {
        final appState = container.read(appStateProvider.notifier);
        if (appState.session != null) {
          await _registerToken(token, container);
        }
      }
    } catch (e) {
      // Push permissions are non-critical -- e.g. simulators don't support
      // APNs, and Firebase may not be configured yet.
      developer.log(
        'Push token load skipped or failed: $e',
        name: 'Bootstrap',
        level: 800,
      );
    }
  }

  // ---- Public helpers -----------------------------------------------------

  /// Registers the cached push token with the backend if available.
  ///
  /// Call this after a successful login to ensure the backend knows
  /// about this device's push token.
  static Future<void> registerPushTokenIfNeeded(
    ProviderContainer container,
  ) async {
    try {
      // Refresh the token in case it changed since bootstrap.
      final token = _cachedPushToken ??
          await PushNotificationService.instance.getPushToken();

      if (token == null) {
        developer.log(
          'No push token available for registration.',
          name: 'Bootstrap',
        );
        return;
      }

      _cachedPushToken = token;
      await _registerToken(token, container);
    } catch (e) {
      developer.log(
        'Push token registration failed: $e',
        name: 'Bootstrap',
        level: 800,
      );
    }
  }

  /// Refreshes app-shell unread badges from the live notification center.
  ///
  /// This runs during launch when an existing session was restored, and can
  /// also be called after login. Failures are non-fatal because notification
  /// badges should never block app startup or route rendering.
  static Future<void> syncUnreadCountsIfNeeded(
    ProviderContainer container,
  ) async {
    final appState = container.read(appStateProvider.notifier);
    if (appState.session == null) return;

    try {
      final api = NotificationApiService(container.read(dioProvider));
      final counts = await api.fetchUnreadCount();
      appState.updateUnreadCounts(
        community: counts.community,
        events: counts.followedEvents,
        djs: counts.followedDJs,
        brands: counts.followedBrands,
      );
      await _syncSystemBadgeFromCounts(counts);
    } catch (e) {
      developer.log(
        'Unread badge sync failed: $e',
        name: 'Bootstrap',
        level: 800,
      );
    }
  }

  static Future<void> _syncSystemBadgeFromCounts(
    NotificationUnreadCount counts,
  ) {
    return AppBadgeService.setBadgeCount(
      counts.community +
          counts.followedEvents +
          counts.followedDJs +
          counts.followedBrands,
    );
  }

  /// Determines the platform string for push token registration.
  static String _platformString() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    // HarmonyOS will be detected once the Flutter SDK exposes a platform enum.
    return 'harmony';
  }

  /// Sets up Firebase Cloud Messaging deep link handling.
  ///
  /// When the user taps a push notification while the app is in the background
  /// or terminated, the notification payload's `deepLink` field (if present)
  /// is resolved via [DeepLinkHandler] and navigated to using [GoRouter].
  ///
  /// Call this after the [ProviderContainer] and router are fully initialised
  /// (i.e. after [runApp]).
  static void setupPushNotificationDeepLinks(ProviderContainer container) {
    try {
      final pushService = PushNotificationService.instance;

      // Mirror iOS foreground presentation by keeping badges fresh when FCM
      // delivers a message while the app is active.
      pushService.listenToForegroundMessages((message) async {
        final appPath = await handleForegroundPushMessageData(
          container,
          message.data,
        );
        developer.log(
          'Foreground push received${appPath == null ? "" : " -> $appPath"}',
          name: 'Bootstrap',
        );
      });

      // Handle taps on notifications that opened the app from background.
      pushService.listenToMessageOpenedApp((message) async {
        final appPath = await resolvePushMessageAppPath(
          container,
          message.data,
          channel: 'push',
        );
        if (appPath == null) return;

        developer.log(
          'Push notification tap -> $appPath',
          name: 'Bootstrap',
        );

        final router = container.read(routerProvider);
        router.go(appPath);
      });

      developer.log(
        'Push notification deep link handler registered.',
        name: 'Bootstrap',
      );
    } catch (e) {
      developer.log(
        'Push notification deep link setup failed: $e',
        name: 'Bootstrap',
        level: 800,
      );
    }
  }

  /// Handles a foreground push payload without navigating away from the
  /// user's current screen.
  ///
  /// Returns the resolved app path for diagnostics/tests; callers should not
  /// auto-navigate on foreground delivery because iOS shows the notification
  /// and waits for an explicit user tap.
  static Future<String?> handleForegroundPushMessageData(
    ProviderContainer container,
    Map<String, dynamic> data,
  ) async {
    await syncUnreadCountsIfNeeded(container);
    return resolvePushMessageAppPath(
      container,
      data,
      channel: 'foreground_push',
    );
  }

  static Future<String?> resolvePushMessageAppPath(
    ProviderContainer container,
    Map<String, dynamic> data, {
    String channel = 'push',
  }) async {
    final directPath = PushRouter.resolvePathFromData(data);
    final uri = _pushPayloadUri(data);
    if (uri == null) return directPath;

    try {
      final resolver = ShareLinkResolver(container.read(dioProvider));
      return await resolver.resolve(uri, channel: channel) ?? directPath;
    } catch (e) {
      developer.log(
        'Push link resolution failed: $e',
        name: 'Bootstrap',
        level: 800,
      );
      return directPath;
    }
  }

  static Uri? _pushPayloadUri(Map<String, dynamic> data) {
    for (final key in const [
      'route',
      'path',
      'deeplink',
      'deepLink',
      'deep_link',
      'link',
      'url',
      'appLink',
      'app_link',
    ]) {
      final value = data[key];
      if (value is! String || value.trim().isEmpty) continue;
      final trimmed = value.trim();
      if (trimmed.startsWith('/')) continue;
      return Uri.tryParse(trimmed);
    }
    return null;
  }

  static Future<void> _registerToken(
    String token,
    ProviderContainer container,
  ) async {
    try {
      final dio = container.read(dioProvider);
      final api = NotificationApiService(dio);
      await api.registerPushToken(
        token: token,
        platform: _platformString(),
      );
      developer.log(
        'Push token registered successfully.',
        name: 'Bootstrap',
      );
    } catch (e) {
      developer.log(
        'Push token backend registration failed: $e',
        name: 'Bootstrap',
        level: 800,
      );
    }
  }

  static Session _sessionFromAuthPayload(Map<String, dynamic> payload) {
    final accessToken =
        payload['accessToken'] as String? ?? payload['token'] as String? ?? '';
    final refreshToken = payload['refreshToken'] as String? ?? '';
    final expiresIn = payload['expiresIn'] as int? ??
        payload['accessTokenExpiresIn'] as int? ??
        3600;
    final userPayload = payload['user'];
    final user = userPayload is Map<String, dynamic>
        ? UserSummary.fromJson(userPayload)
        : const UserSummary(id: '', username: '', displayName: '');

    return Session(
      token: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresIn: expiresIn,
      user: user,
    );
  }
}
