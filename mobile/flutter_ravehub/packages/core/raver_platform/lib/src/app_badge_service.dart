import 'dart:developer' as developer;

import 'package:flutter/services.dart';

/// Synchronizes the launcher/app-icon badge count with in-app unread counts.
class AppBadgeService {
  AppBadgeService._();

  static const _channel = MethodChannel('com.ravehub.app_badge');

  /// Sets the app icon badge count.
  ///
  /// Negative counts are normalized to zero. Missing native support is treated
  /// as non-fatal so Android/Harmony/web builds can safely no-op.
  static Future<void> setBadgeCount(int count) async {
    final normalized = count < 0 ? 0 : count;
    try {
      await _channel.invokeMethod<void>(
        'setBadgeCount',
        {'count': normalized},
      );
    } on MissingPluginException {
      developer.log(
        'App badge channel not registered',
        name: 'AppBadgeService',
        level: 700,
      );
    } on PlatformException catch (error) {
      developer.log(
        'App badge update failed: $error',
        name: 'AppBadgeService',
        level: 800,
      );
    }
  }

  /// Clears the app icon badge.
  static Future<void> clearBadge() => setBadgeCount(0);
}
