import 'package:flutter/material.dart';

import 'raver_colors.dart';
import 'raver_typography.dart';

/// A [ThemeExtension] that carries every RaveHub design-system token.
///
/// Obtain via `Theme.of(context).extension<RaverThemeData>()` or the
/// convenience getter `context.raver`.
class RaverThemeData extends ThemeExtension<RaverThemeData> {
  const RaverThemeData({
    required this.background,
    required this.card,
    required this.cardBorder,
    required this.primaryText,
    required this.secondaryText,
    required this.accent,
    required this.tabBarChromeStart,
    required this.tabBarChromeEnd,
    required this.tabBarSelectionStart,
    required this.tabBarSelectionEnd,
    required this.tabBarStrokeLeading,
    required this.tabBarStrokeTrailing,
    required this.tabBarSelectionStroke,
    required this.tabBarShadowPrimary,
    required this.tabBarShadowAccent,
  });

  // ---------------------------------------------------------------------------
  // Tokens
  // ---------------------------------------------------------------------------

  final Color background;
  final Color card;
  final Color cardBorder;
  final Color primaryText;
  final Color secondaryText;
  final Color accent;
  final Color tabBarChromeStart;
  final Color tabBarChromeEnd;
  final Color tabBarSelectionStart;
  final Color tabBarSelectionEnd;
  final Color tabBarStrokeLeading;
  final Color tabBarStrokeTrailing;
  final Color tabBarSelectionStroke;
  final Color tabBarShadowPrimary;
  final Color tabBarShadowAccent;

  /// Backwards-compatible divider token.
  Color get divider => cardBorder;

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  /// Light-mode token values.
  static RaverThemeData light() {
    const b = Brightness.light;
    return RaverThemeData(
      background: RaverColors.background(b),
      card: RaverColors.card(b),
      cardBorder: RaverColors.cardBorder(b),
      primaryText: RaverColors.primaryText(b),
      secondaryText: RaverColors.secondaryText(b),
      accent: RaverColors.accent(b),
      tabBarChromeStart: RaverColors.tabBarChromeStart(b),
      tabBarChromeEnd: RaverColors.tabBarChromeEnd(b),
      tabBarSelectionStart: RaverColors.tabBarSelectionStart(b),
      tabBarSelectionEnd: RaverColors.tabBarSelectionEnd(b),
      tabBarStrokeLeading: RaverColors.tabBarStrokeLeading(b),
      tabBarStrokeTrailing: RaverColors.tabBarStrokeTrailing(b),
      tabBarSelectionStroke: RaverColors.tabBarSelectionStroke(b),
      tabBarShadowPrimary: RaverColors.tabBarShadowPrimary(b),
      tabBarShadowAccent: RaverColors.tabBarShadowAccent(b),
    );
  }

  /// Dark-mode token values.
  static RaverThemeData dark() {
    const b = Brightness.dark;
    return RaverThemeData(
      background: RaverColors.background(b),
      card: RaverColors.card(b),
      cardBorder: RaverColors.cardBorder(b),
      primaryText: RaverColors.primaryText(b),
      secondaryText: RaverColors.secondaryText(b),
      accent: RaverColors.accent(b),
      tabBarChromeStart: RaverColors.tabBarChromeStart(b),
      tabBarChromeEnd: RaverColors.tabBarChromeEnd(b),
      tabBarSelectionStart: RaverColors.tabBarSelectionStart(b),
      tabBarSelectionEnd: RaverColors.tabBarSelectionEnd(b),
      tabBarStrokeLeading: RaverColors.tabBarStrokeLeading(b),
      tabBarStrokeTrailing: RaverColors.tabBarStrokeTrailing(b),
      tabBarSelectionStroke: RaverColors.tabBarSelectionStroke(b),
      tabBarShadowPrimary: RaverColors.tabBarShadowPrimary(b),
      tabBarShadowAccent: RaverColors.tabBarShadowAccent(b),
    );
  }

  // ---------------------------------------------------------------------------
  // Full ThemeData factories
  // ---------------------------------------------------------------------------

  /// A complete [ThemeData] configured for light mode.
  static ThemeData lightTheme() {
    final raver = RaverThemeData.light();
    return _buildThemeData(Brightness.light, raver);
  }

  /// A complete [ThemeData] configured for dark mode.
  static ThemeData darkTheme() {
    final raver = RaverThemeData.dark();
    return _buildThemeData(Brightness.dark, raver);
  }

  static ThemeData _buildThemeData(
      Brightness brightness, RaverThemeData raver) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: raver.accent,
      brightness: brightness,
      surface: raver.card,
      primary: raver.accent,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: raver.background,
      cardColor: raver.card,
      dividerColor: raver.cardBorder,
      splashFactory: InkSparkle.splashFactory,
      textTheme: TextTheme(
        headlineLarge: RaverTypography.headline(
          color: raver.primaryText,
        ),
        titleLarge: RaverTypography.title(
          color: raver.primaryText,
        ),
        titleMedium: RaverTypography.title(
          size: 16,
          color: raver.primaryText,
        ),
        bodyLarge: RaverTypography.body(
          color: raver.primaryText,
        ),
        bodyMedium: RaverTypography.body(
          size: 14,
          color: raver.primaryText,
        ),
        bodySmall: RaverTypography.caption(
          color: raver.secondaryText,
        ),
        labelLarge: RaverTypography.label(
          color: raver.primaryText,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: raver.background,
        foregroundColor: raver.primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: RaverTypography.title(
          color: raver.primaryText,
        ),
      ),
      cardTheme: CardThemeData(
        color: raver.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: raver.cardBorder),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: raver.accent,
        unselectedItemColor: raver.secondaryText,
        elevation: 0,
      ),
      extensions: [raver],
    );
  }

  // ---------------------------------------------------------------------------
  // ThemeExtension overrides
  // ---------------------------------------------------------------------------

  @override
  RaverThemeData copyWith({
    Color? background,
    Color? card,
    Color? cardBorder,
    Color? primaryText,
    Color? secondaryText,
    Color? accent,
    Color? tabBarChromeStart,
    Color? tabBarChromeEnd,
    Color? tabBarSelectionStart,
    Color? tabBarSelectionEnd,
    Color? tabBarStrokeLeading,
    Color? tabBarStrokeTrailing,
    Color? tabBarSelectionStroke,
    Color? tabBarShadowPrimary,
    Color? tabBarShadowAccent,
  }) {
    return RaverThemeData(
      background: background ?? this.background,
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      accent: accent ?? this.accent,
      tabBarChromeStart: tabBarChromeStart ?? this.tabBarChromeStart,
      tabBarChromeEnd: tabBarChromeEnd ?? this.tabBarChromeEnd,
      tabBarSelectionStart: tabBarSelectionStart ?? this.tabBarSelectionStart,
      tabBarSelectionEnd: tabBarSelectionEnd ?? this.tabBarSelectionEnd,
      tabBarStrokeLeading: tabBarStrokeLeading ?? this.tabBarStrokeLeading,
      tabBarStrokeTrailing: tabBarStrokeTrailing ?? this.tabBarStrokeTrailing,
      tabBarSelectionStroke:
          tabBarSelectionStroke ?? this.tabBarSelectionStroke,
      tabBarShadowPrimary: tabBarShadowPrimary ?? this.tabBarShadowPrimary,
      tabBarShadowAccent: tabBarShadowAccent ?? this.tabBarShadowAccent,
    );
  }

  @override
  RaverThemeData lerp(covariant RaverThemeData? other, double t) {
    if (other == null) return this;
    return RaverThemeData(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      tabBarChromeStart:
          Color.lerp(tabBarChromeStart, other.tabBarChromeStart, t)!,
      tabBarChromeEnd: Color.lerp(tabBarChromeEnd, other.tabBarChromeEnd, t)!,
      tabBarSelectionStart:
          Color.lerp(tabBarSelectionStart, other.tabBarSelectionStart, t)!,
      tabBarSelectionEnd:
          Color.lerp(tabBarSelectionEnd, other.tabBarSelectionEnd, t)!,
      tabBarStrokeLeading:
          Color.lerp(tabBarStrokeLeading, other.tabBarStrokeLeading, t)!,
      tabBarStrokeTrailing:
          Color.lerp(tabBarStrokeTrailing, other.tabBarStrokeTrailing, t)!,
      tabBarSelectionStroke:
          Color.lerp(tabBarSelectionStroke, other.tabBarSelectionStroke, t)!,
      tabBarShadowPrimary:
          Color.lerp(tabBarShadowPrimary, other.tabBarShadowPrimary, t)!,
      tabBarShadowAccent:
          Color.lerp(tabBarShadowAccent, other.tabBarShadowAccent, t)!,
    );
  }
}

// ---------------------------------------------------------------------------
// BuildContext convenience
// ---------------------------------------------------------------------------

/// Convenience extension to access [RaverThemeData] tokens from any widget.
///
/// ```dart
/// final bg = context.raver.background;
/// ```
extension RaverThemeContext on BuildContext {
  /// The current [RaverThemeData] from the nearest [Theme] ancestor.
  RaverThemeData get raver =>
      Theme.of(this).extension<RaverThemeData>() ?? RaverThemeData.light();
}
