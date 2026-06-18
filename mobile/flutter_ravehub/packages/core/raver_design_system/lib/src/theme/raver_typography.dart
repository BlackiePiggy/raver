import 'package:flutter/material.dart';

/// Typography tokens for the RaveHub design system.
///
/// The brand font is Futura Condensed Extra Bold. If the font is not available
/// on the current platform, Flutter falls back to the system default with
/// heavy weight.
class RaverTypography {
  const RaverTypography._();

  /// The brand typeface name.
  ///
  /// On iOS this resolves to the system-installed Futura; on other platforms
  /// the bundled asset (or system fallback) is used.
  static const String _brandFamily = 'Futura-CondensedExtraBold';

  /// The display name of the application, rendered using the brand font.
  static const String appName = 'RaveHub';

  // ---------------------------------------------------------------------------
  // Brand font
  // ---------------------------------------------------------------------------

  /// Returns the brand typeface at the given [size].
  static TextStyle brandFont({
    double size = 20,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: _brandFamily,
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: 0.4,
    );
  }

  // ---------------------------------------------------------------------------
  // Semantic styles
  // ---------------------------------------------------------------------------

  /// Large headlines, e.g. screen titles.
  static TextStyle headline({
    double size = 28,
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.3,
      height: 1.2,
    );
  }

  /// Section titles and navigation bar titles.
  static TextStyle title({
    double size = 18,
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.2,
      height: 1.3,
    );
  }

  /// Body text for content paragraphs.
  static TextStyle body({
    double size = 16,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.5,
    );
  }

  /// Material-style medium body alias.
  static TextStyle bodyMedium({
    double size = 14,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) =>
      body(size: size, color: color, weight: weight);

  /// Material-style small headline alias.
  static TextStyle headlineSmall({
    double size = 24,
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) =>
      headline(size: size, color: color, weight: weight);

  /// Small secondary labels and timestamps.
  static TextStyle caption({
    double size = 12,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.4,
    );
  }

  /// Button / action labels.
  static TextStyle label({
    double size = 14,
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0.1,
      height: 1.2,
    );
  }

  /// Tab bar item labels.
  static TextStyle tabLabel({
    double size = 10,
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.0,
    );
  }
}
