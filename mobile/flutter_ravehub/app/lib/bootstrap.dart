import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:feature_inbox/feature_inbox.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_platform/raver_platform.dart';
import 'package:ravehub/di/app_providers.dart';
import 'package:ravehub/router/deep_link_handler.dart';

/// Performs one-time app initialisation on startup.
///
/// Called from `main()` after [WidgetsFlutterBinding.ensureInitialized] and
/// before [runApp]. The steps mirror the iOS `AppBootstrapper`:
///
///  1. Restore the persisted session from secure storage.
///  2. Restore language and appearance preferences from SharedPreferences.
///  3. Request push notification permissions.
///
/// All steps are best-effort: failures are logged but do not prevent the app
/// from launching.
class AppBootstrap {
  const AppBootstrap._();

  /// Cached push token for deferred registration (e.g. after login).
  static String? _cachedPushToken;

  /// Runs the full bootstrap sequence.
  static Future<void> run(ProviderContainer container) async {
    await Future.wait([
      _restoreSession(container),
      _restorePreferences(container),
    ]);

    // Push permission is requested after session/prefs are ready so that
    // the language is set for any permission dialogs shown by the OS.
    await _requestPushPermission(container);
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

  static Future<void> _requestPushPermission(
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
        'Push permission request skipped or failed: $e',
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
      final token =
          _cachedPushToken ?? await PushNotificationService.instance.getPushToken();

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

      // Handle taps on notifications that opened the app from background.
      pushService.onNotificationTapped((Map<String, dynamic> data) {
        final deepLink = data['deepLink'] as String?;
        if (deepLink == null || deepLink.isEmpty) return;

        final uri = Uri.tryParse(deepLink);
        if (uri == null) return;

        final appPath = DeepLinkHandler.toAppPath(uri);
        if (appPath == null) return;

        developer.log(
          'Push deep link: $deepLink -> $appPath',
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
}
