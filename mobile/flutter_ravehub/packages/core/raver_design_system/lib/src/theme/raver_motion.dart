import 'package:flutter/animation.dart';

/// Motion / animation tokens for the RaveHub design system.
///
/// Provides consistent durations and curves across all animated transitions.
class RaverMotion {
  const RaverMotion._();

  // ---------------------------------------------------------------------------
  // Durations
  // ---------------------------------------------------------------------------

  /// Quick micro-interactions (e.g. icon colour change, check toggle).
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard transitions (e.g. tab switch, indicator slide).
  static const Duration normal = Duration(milliseconds: 200);

  /// Deliberate transitions (e.g. page transitions, overlay reveals).
  static const Duration slow = Duration(milliseconds: 300);

  /// Long-running or spring-like transitions.
  static const Duration extraSlow = Duration(milliseconds: 500);

  // ---------------------------------------------------------------------------
  // Curves
  // ---------------------------------------------------------------------------

  /// Default easing curve.
  static const Curve curve = Curves.easeInOut;

  /// Deceleration curve for entering elements.
  static const Curve decelerate = Curves.easeOut;

  /// Acceleration curve for exiting elements.
  static const Curve accelerate = Curves.easeIn;

  /// Spring-like overshoot curve for playful interactions.
  static const Curve spring = Curves.elasticOut;
}
