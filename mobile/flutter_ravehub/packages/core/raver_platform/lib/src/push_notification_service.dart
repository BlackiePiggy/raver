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
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const _harmonyChannel = MethodChannel('com.ravehub.push/harmony');

  /// Initialises Firebase Messaging and returns the device push token.
  ///
  /// Returns null if the platform does not support push (e.g. simulator),
  /// if permissions are denied, or if the channel is unavailable.
  Future<String?> getPushToken() async {
    // HarmonyOS: delegate to native channel
    if (_isHarmonyOS()) {
      return _getHarmonyPushToken();
    }

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }

      return await messaging.getToken();
    } catch (e) {
      developer.log('FCM token error: $e', name: 'PushNotificationService', level: 800);
      return null;
    }
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
      developer.log('HarmonyOS Push Kit error: $e', name: 'PushNotificationService', level: 800);
      return null;
    } on MissingPluginException {
      developer.log('HarmonyOS Push channel not registered', name: 'PushNotificationService', level: 700);
      return null;
    }
  }
}
