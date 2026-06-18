import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/raver_theme.dart';

/// A glassmorphic card with a frosted-glass backdrop blur, translucent fill,
/// and subtle gradient border.
///
/// Used throughout RaveHub for elevated content containers that sit above
/// blurred backgrounds.
class GlassCard extends StatelessWidget {
  /// Creates a [GlassCard].
  const GlassCard({
    required this.child,
    super.key,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(16),
    this.blurSigma = 24,
    this.fillOpacity,
    this.margin,
  });

  /// The content to display inside the card.
  final Widget child;

  /// Corner radius applied to the card shape.
  final double borderRadius;

  /// Inner padding around [child].
  final EdgeInsets padding;

  /// Gaussian blur sigma for the backdrop filter.
  final double blurSigma;

  /// Override for the translucent fill opacity. When `null`, a sensible
  /// default is chosen based on the current brightness.
  final double? fillOpacity;

  /// Optional outer margin.
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final brightness = Theme.of(context).brightness;

    final effectiveFillOpacity =
        fillOpacity ?? (brightness == Brightness.light ? 0.70 : 0.45);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.card.withValues(alpha: effectiveFillOpacity),
                  theme.card.withValues(
                    alpha: effectiveFillOpacity * 0.8,
                  ),
                ],
              ),
              border: Border.all(
                color: theme.cardBorder,
              ),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
