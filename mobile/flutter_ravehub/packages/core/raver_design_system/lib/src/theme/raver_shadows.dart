import 'dart:ui';

import 'package:flutter/material.dart';

import 'raver_colors.dart';

/// Predefined shadow configurations for the RaveHub design system.
///
/// Follows the iOS dual-shadow pattern: a neutral depth shadow combined with
/// a coloured accent glow.
class RaverShadows {
  const RaverShadows._();

  // ---------------------------------------------------------------------------
  // Tab bar
  // ---------------------------------------------------------------------------

  /// Dual shadow for the floating tab bar.
  ///
  /// The first shadow provides neutral depth; the second adds a subtle
  /// accent glow that reinforces the brand colour.
  static List<BoxShadow> tabBar(Brightness brightness) => [
        BoxShadow(
          color: RaverColors.tabBarShadowPrimary(brightness),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: RaverColors.tabBarShadowAccent(brightness),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  // ---------------------------------------------------------------------------
  // Card
  // ---------------------------------------------------------------------------

  /// Subtle card elevation shadow.
  static List<BoxShadow> card(Brightness brightness) => [
        BoxShadow(
          color: brightness == Brightness.light
              ? const Color.fromRGBO(0, 0, 0, 0.06)
              : const Color.fromRGBO(0, 0, 0, 0.30),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: brightness == Brightness.light
              ? const Color.fromRGBO(107, 66, 219, 0.04)
              : const Color.fromRGBO(140, 92, 245, 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  // ---------------------------------------------------------------------------
  // Button
  // ---------------------------------------------------------------------------

  /// Shadow for elevated (primary) buttons.
  static List<BoxShadow> button(Brightness brightness) => [
        BoxShadow(
          color: brightness == Brightness.light
              ? const Color.fromRGBO(107, 66, 219, 0.30)
              : const Color.fromRGBO(140, 92, 245, 0.35),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // ---------------------------------------------------------------------------
  // Overlay
  // ---------------------------------------------------------------------------

  /// Deep shadow for modals and overlays.
  static List<BoxShadow> overlay(Brightness brightness) => [
        BoxShadow(
          color: brightness == Brightness.light
              ? const Color.fromRGBO(0, 0, 0, 0.16)
              : const Color.fromRGBO(0, 0, 0, 0.50),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ];
}
