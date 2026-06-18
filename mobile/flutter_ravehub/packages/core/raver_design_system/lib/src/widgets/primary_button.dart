import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raver_platform/raver_platform.dart';

import '../theme/raver_motion.dart';
import '../theme/raver_shadows.dart';
import '../theme/raver_theme.dart';
import '../theme/raver_typography.dart';

/// Visual variants supported by [PrimaryButton].
enum PrimaryButtonVariant {
  /// Filled gradient button.
  filled,

  /// Outlined button.
  outline,
}

/// A gradient accent button matching the iOS PrimaryButtonStyle.
///
/// Renders as a rounded capsule with a linear gradient fill using the
/// accent colour and a subtle shadow.
class PrimaryButton extends StatefulWidget {
  /// Creates a [PrimaryButton].
  const PrimaryButton({
    required this.label,
    super.key,
    this.onPressed,
    this.onTap,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.height = 48,
    this.borderRadius = 24,
    this.variant = PrimaryButtonVariant.filled,
  });

  /// Button label text.
  final String label;

  /// Called when the button is tapped (if not loading).
  final VoidCallback? onPressed;

  /// Backwards-compatible alias for [onPressed].
  final VoidCallback? onTap;

  /// Optional leading icon.
  final IconData? icon;

  /// When `true`, a circular progress indicator replaces the label.
  final bool isLoading;

  /// When `true`, the button stretches to fill the available width.
  final bool isExpanded;

  /// Button height.
  final double height;

  /// Corner radius.
  final double borderRadius;

  /// Visual style of the button.
  final PrimaryButtonVariant variant;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) => setState(() => _isPressed = true);
  void _handleTapUp(TapUpDetails _) => setState(() => _isPressed = false);
  void _handleTapCancel() => setState(() => _isPressed = false);

  void _handleTap(VoidCallback callback) {
    unawaited(HapticService.lightImpact());
    callback();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final brightness = Theme.of(context).brightness;
    final callback = widget.onPressed ?? widget.onTap;
    final enabled = callback != null && !widget.isLoading;

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        theme.accent,
        HSLColor.fromColor(theme.accent)
            .withLightness(
              (HSLColor.fromColor(theme.accent).lightness - 0.08)
                  .clamp(0.0, 1.0),
            )
            .toColor(),
      ],
    );

    final child = AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: RaverMotion.fast,
      curve: RaverMotion.curve,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.5,
        duration: RaverMotion.fast,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.variant == PrimaryButtonVariant.outline
                ? Colors.transparent
                : null,
            gradient: widget.variant == PrimaryButtonVariant.outline
                ? null
                : gradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.variant == PrimaryButtonVariant.outline
                ? Border.all(color: theme.accent, width: 1.2)
                : null,
            boxShadow: enabled ? RaverShadows.button(brightness) : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? () => _handleTap(callback) : null,
              onTapDown: enabled ? _handleTapDown : null,
              onTapUp: enabled ? _handleTapUp : null,
              onTapCancel: enabled ? _handleTapCancel : null,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              splashColor: Colors.white.withValues(alpha: 0.15),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: widget.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: widget.isExpanded
                              ? MainAxisSize.max
                              : MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(
                                widget.icon,
                                size: 18,
                                color:
                                    widget.variant == PrimaryButtonVariant.outline
                                        ? theme.accent
                                        : Colors.white,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              widget.label,
                              style: RaverTypography.label(
                                color:
                                    widget.variant == PrimaryButtonVariant.outline
                                        ? theme.accent
                                        : Colors.white,
                                size: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return widget.isExpanded
        ? SizedBox(width: double.infinity, child: child)
        : child;
  }
}
