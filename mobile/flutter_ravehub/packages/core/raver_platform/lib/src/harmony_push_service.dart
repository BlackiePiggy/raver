import 'package:flutter/services.dart';

// HarmonyOS Push Kit adapter.
// Uses MethodChannel 'com.ravehub.push/harmony' (already defined in PushNotificationService).
//
// On the native side (entry/src/main/ets/), the HarmonyOS app must:
// 1. Call Push Kit's requestEnablePush()
// 2. Call getToken() to obtain a push token
// 3. Send token to the Flutter side via MethodChannel.invokeMethod('getPushToken')
// 4. In onReceiveMessage(), forward the RemoteMessage to Flutter via 'onMessage' event channel
//
// This class provides the Dart-side documentation and fallback implementation.

/// Adapter for HarmonyOS Push Kit, providing push token retrieval via a
/// platform channel.
///
/// The native HarmonyOS module (PushKitAbility.ets) is responsible for
/// requesting push permissions, obtaining the token from Push Kit, and
/// forwarding it through the `com.ravehub.push/harmony` method channel.
///
/// On non-HarmonyOS platforms, [getToken] returns `null` immediately because
/// the channel handler is not registered, triggering [MissingPluginException].
class HarmonyPushAdapter {
  static const _channel = MethodChannel('com.ravehub.push/harmony');

  /// Request permission and retrieve the HarmonyOS Push Kit token.
  /// Returns null if Push Kit is not available or permission denied.
  static Future<String?> getToken() async {
    try {
      return await _channel.invokeMethod<String>('getPushToken');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null; // Not on HarmonyOS
    }
  }

  /// Subscribe to a push topic for targeted notifications.
  /// Returns `true` if the subscription succeeded, `false` otherwise.
  static Future<bool> subscribeToTopic(String topic) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'subscribeToTopic',
        <String, String>{'topic': topic},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Unsubscribe from a push topic.
  /// Returns `true` if the unsubscription succeeded, `false` otherwise.
  static Future<bool> unsubscribeFromTopic(String topic) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'unsubscribeFromTopic',
        <String, String>{'topic': topic},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Delete the current push token (e.g. on logout).
  /// The next call to [getToken] will request a fresh token from Push Kit.
  static Future<void> deleteToken() async {
    try {
      await _channel.invokeMethod<void>('deleteToken');
    } on PlatformException {
      // Silently ignore — token deletion is best-effort.
    } on MissingPluginException {
      // Not on HarmonyOS.
    }
  }
}
