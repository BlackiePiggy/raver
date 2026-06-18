import 'package:flutter/services.dart';

/// Native haptic feedback bridge for iOS-like selection and press feedback.
class HapticService {
  const HapticService._();

  /// Light feedback for ordinary button taps.
  static Future<void> lightImpact() => HapticFeedback.lightImpact();

  /// Medium feedback for prominent actions.
  static Future<void> mediumImpact() => HapticFeedback.mediumImpact();

  /// Selection feedback for tabs, segmented controls, and pickers.
  static Future<void> selectionClick() => HapticFeedback.selectionClick();
}
