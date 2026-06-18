import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Handles FCM push notification token retrieval and foreground message routing.
///
/// On HarmonyOS (detected via [defaultTargetPlatform]), the class falls back
/// to a Platform Channel call to the native HarmonyOS Push Kit bridge, which
/// must be registered in the host app's native code. If the channel is not
/// available, token registration is silently skipped.
class PushNotificationService {
  PushNotificationService._({
    _PushMessagingClient? messagingClient,
  }) : _messagingClient = messagingClient ?? _FirebasePushMessagingClient();

  @visibleForTesting
  PushNotificationService.testing({
    required Future<NotificationSettings> Function() getNotificationSettings,
    required Future<NotificationSettings> Function() requestPermission,
    required Future<void> Function()
        setForegroundNotificationPresentationOptions,
    required Future<String?> Function() getToken,
  }) : _messagingClient = _CallbackPushMessagingClient(
          getNotificationSettings: getNotificationSettings,
          requestPermission: requestPermission,
          setForegroundNotificationPresentationOptions:
              setForegroundNotificationPresentationOptions,
          getToken: getToken,
        );

  static final PushNotificationService instance = PushNotificationService._();

  static const _harmonyChannel = MethodChannel('com.ravehub.push/harmony');

  final _PushMessagingClient _messagingClient;

  /// Initialises Firebase Messaging and returns the device push token.
  ///
  /// Returns null if the platform does not support push (e.g. simulator),
  /// if permissions are denied, or if the channel is unavailable.
  ///
  /// By default this method only checks the current notification authorization
  /// state, matching the native iOS app's deferred permission prompt. Pass
  /// [requestPermission] when the call is triggered by explicit user intent.
  Future<String?> getPushToken({bool requestPermission = false}) async {
    // HarmonyOS: delegate to native channel
    if (_isHarmonyOS()) {
      return _getHarmonyPushToken();
    }

    try {
      final settings = requestPermission
          ? await _messagingClient.requestPermission()
          : await _messagingClient.getNotificationSettings();
      await _messagingClient.setForegroundNotificationPresentationOptions();

      if (!_canFetchPushToken(settings.authorizationStatus)) {
        return null;
      }

      return await _messagingClient.getToken();
    } catch (e) {
      developer.log(
        'FCM token error: $e',
        name: 'PushNotificationService',
        level: 800,
      );
      return null;
    }
  }

  static bool _canFetchPushToken(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  /// Listens to incoming foreground messages and calls [onMessage].
  void listenToForegroundMessages(void Function(RemoteMessage) onMessage) {
    if (_isHarmonyOS()) return;
    FirebaseMessaging.onMessage.listen(onMessage);
  }

  /// Listens to notification-tap events that open the app from background.
  void listenToMessageOpenedApp(void Function(RemoteMessage) onOpened) {
    if (_isHarmonyOS()) return;
    FirebaseMessaging.onMessageOpenedApp.listen(onOpened);
  }

  static bool _isHarmonyOS() {
    // HarmonyOS is identified by the 'ohos' platform string at runtime.
    // Flutter's defaultTargetPlatform does not have a HarmonyOS entry yet;
    // use the platform channel as a sentinel instead.
    return false; // Extend when HarmonyOS Flutter SDK exposes a platform enum.
  }

  Future<String?> _getHarmonyPushToken() async {
    try {
      final token = await _harmonyChannel.invokeMethod<String>('getPushToken');
      return token;
    } on PlatformException catch (e) {
      developer.log(
        'HarmonyOS Push Kit error: $e',
        name: 'PushNotificationService',
        level: 800,
      );
      return null;
    } on MissingPluginException {
      developer.log(
        'HarmonyOS Push channel not registered',
        name: 'PushNotificationService',
        level: 700,
      );
      return null;
    }
  }
}

abstract class _PushMessagingClient {
  Future<NotificationSettings> getNotificationSettings();

  Future<NotificationSettings> requestPermission();

  Future<void> setForegroundNotificationPresentationOptions();

  Future<String?> getToken();
}

class _FirebasePushMessagingClient implements _PushMessagingClient {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<NotificationSettings> getNotificationSettings() {
    return _messaging.getNotificationSettings();
  }

  @override
  Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  @override
  Future<void> setForegroundNotificationPresentationOptions() {
    return _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  @override
  Future<String?> getToken() {
    return _messaging.getToken();
  }
}

class _CallbackPushMessagingClient implements _PushMessagingClient {
  const _CallbackPushMessagingClient({
    required Future<NotificationSettings> Function() getNotificationSettings,
    required Future<NotificationSettings> Function() requestPermission,
    required Future<void> Function()
        setForegroundNotificationPresentationOptions,
    required Future<String?> Function() getToken,
  })  : _getNotificationSettings = getNotificationSettings,
        _requestPermission = requestPermission,
        _setForegroundNotificationPresentationOptions =
            setForegroundNotificationPresentationOptions,
        _getToken = getToken;

  final Future<NotificationSettings> Function() _getNotificationSettings;
  final Future<NotificationSettings> Function() _requestPermission;
  final Future<void> Function() _setForegroundNotificationPresentationOptions;
  final Future<String?> Function() _getToken;

  @override
  Future<NotificationSettings> getNotificationSettings() {
    return _getNotificationSettings();
  }

  @override
  Future<NotificationSettings> requestPermission() {
    return _requestPermission();
  }

  @override
  Future<void> setForegroundNotificationPresentationOptions() {
    return _setForegroundNotificationPresentationOptions();
  }

  @override
  Future<String?> getToken() {
    return _getToken();
  }
}
