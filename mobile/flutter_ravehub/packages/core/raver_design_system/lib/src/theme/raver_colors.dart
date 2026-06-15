import 'dart:ui';

/// All colour tokens for the RaveHub design system.
///
/// Each static method takes a [Brightness] so callers can obtain the correct
/// value for light or dark mode without holding a reference to the full theme.
///
/// RGB values are transcribed from the iOS `Theme.swift` specification.
class RaverColors {
  const RaverColors._();

  // ---------------------------------------------------------------------------
  // Surface colours
  // ---------------------------------------------------------------------------

  /// Page / scaffold background.
  static Color background(Brightness brightness) => switch (brightness) {
        Brightness.light => const Color.fromRGBO(247, 247, 251, 1),
        Brightness.dark => const Color.fromRGBO(8, 8, 10, 1),
      };

  /// Card surface.
  static Color card(Brightness brightness) => switch (brightness) {
        Brightness.light => const Color.fromRGBO(255, 255, 255, 1),
        Brightness.dark => const Color.fromRGBO(28, 28, 31, 1),
      };

  /// Card border / divider.
  static Color cardBorder(Brightness brightness) => switch (brightness) {
        Brightness.light => const Color.fromRGBO(0, 0, 0, 0.08),
        Brightness.dark => const Color.fromRGBO(255, 255, 255, 0.10),
      };

  // ---------------------------------------------------------------------------
  // Text colours
  // ---------------------------------------------------------------------------

  /// Primary (high-emphasis) text.
  static Color primaryText(Brightness brightness) => switch (brightness) {
        Brightness.light => const Color.fromRGBO(26, 26, 33, 1),
        Brightness.dark => const Color.fromRGBO(245, 245, 247, 1),
      };

  /// Secondary (medium-emphasis) text.
  static Color secondaryText(Brightness brightness) => switch (brightness) {
        Brightness.light => const Color.fromRGBO(107, 112, 128, 1),
        Brightness.dark => const Color.fromRGBO(163, 163, 173, 1),
      };

  // ---------------------------------------------------------------------------
  // Accent
  // ---------------------------------------------------------------------------

  /// Brand accent colour (purple).
  static Color accent(Brightness brightness) => switch (brightness) {
        Brightness.light => const Color.fromRGBO(107, 66, 219, 1),
        Brightness.dark => const Color.fromRGBO(140, 92, 245, 1),
      };

  // ---------------------------------------------------------------------------
  // Tab-bar chrome
  // ---------------------------------------------------------------------------

  /// Tab-bar glassmorphic background gradient start.
  static Color tabBarChromeStart(Brightness brightness) => switch (brightness) {
        Brightness.light => const Color.fromRGBO(250, 250, 255, 0.86),
        Brightness.dark => const Color.fromRGBO(26, 20, 41, 0.20),
      };

  /// Tab-bar glassmorphic background gradient end.
  static Color tabBarChromeEnd(Brightness brightness) => switch (brightness) {
        Brightness.light => const Color.fromRGBO(237, 232, 252, 0.82),
        Brightness.dark => const Color.fromRGBO(38, 26, 64, 0.20),
      };

  // ---------------------------------------------------------------------------
  // Tab-bar selection indicator
  // ---------------------------------------------------------------------------

  /// Selected-tab capsule gradient start.
  static Color tabBarSelectionStart(Brightness brightness) =>
      switch (brightness) {
        Brightness.light => const Color.fromRGBO(125, 92, 242, 0.92),
        Brightness.dark => const Color.fromRGBO(133, 102, 250, 0.62),
      };

  /// Selected-tab capsule gradient end.
  static Color tabBarSelectionEnd(Brightness brightness) =>
      switch (brightness) {
        Brightness.light => const Color.fromRGBO(97, 69, 224, 0.88),
        Brightness.dark => const Color.fromRGBO(107, 74, 230, 0.56),
      };

  // ---------------------------------------------------------------------------
  // Tab-bar strokes
  // ---------------------------------------------------------------------------

  /// Leading border stroke of the tab bar.
  static Color tabBarStrokeLeading(Brightness brightness) =>
      switch (brightness) {
        Brightness.light => const Color.fromRGBO(255, 255, 255, 0.88),
        Brightness.dark => const Color.fromRGBO(255, 255, 255, 0.24),
      };

  /// Trailing border stroke of the tab bar.
  static Color tabBarStrokeTrailing(Brightness brightness) =>
      switch (brightness) {
        Brightness.light => const Color.fromRGBO(184, 158, 255, 0.18),
        Brightness.dark => const Color.fromRGBO(184, 158, 255, 0.28),
      };

  /// Stroke around the selected tab indicator capsule.
  static Color tabBarSelectionStroke(Brightness brightness) =>
      switch (brightness) {
        Brightness.light => const Color.fromRGBO(255, 255, 255, 0.46),
        Brightness.dark => const Color.fromRGBO(255, 255, 255, 0.18),
      };

  // ---------------------------------------------------------------------------
  // Tab-bar shadows
  // ---------------------------------------------------------------------------

  /// Primary drop shadow beneath the tab bar.
  static Color tabBarShadowPrimary(Brightness brightness) =>
      switch (brightness) {
        Brightness.light => const Color.fromRGBO(0, 0, 0, 0.10),
        Brightness.dark => const Color.fromRGBO(0, 0, 0, 0.46),
      };

  /// Accent glow shadow beneath the tab bar.
  static Color tabBarShadowAccent(Brightness brightness) =>
      switch (brightness) {
        Brightness.light => const Color.fromRGBO(110, 77, 235, 0.10),
        Brightness.dark => const Color.fromRGBO(110, 77, 235, 0.24),
      };
}
