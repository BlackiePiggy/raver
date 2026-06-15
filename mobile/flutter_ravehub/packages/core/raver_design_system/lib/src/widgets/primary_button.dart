import 'package:flutter/material.dart';

import '../theme/raver_motion.dart';
import '../theme/raver_shadows.dart';
import '../theme/raver_theme.dart';
import '../theme/raver_typography.dart';

/// A gradient accent button matching the iOS PrimaryButtonStyle.
///
/// Renders as a rounded capsule with a linear gradient fill using the
/// accent colour and a subtle shadow.
class PrimaryButton extends StatefulWidget {
  /// Creates a [PrimaryButton].
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.height = 48,
    this.borderRadius = 24,
  });

  /// Button label text.
  final String label;

  /// Called when the button is tapped (if not loading).
  final VoidCallback? onPressed;

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

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) => setState(() => _isPressed = true);
  void _handleTapUp(TapUpDetails _) => setState(() => _isPressed = false);
  void _handleTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final brightness = Theme.of(context).brightness;
    final enabled = widget.onPressed != null && !widget.isLoading;

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
            gradient: gradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: enabled ? RaverShadows.button(brightness) : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? widget.onPressed : null,
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
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              widget.label,
                              style: RaverTypography.label(
                                color: Colors.white,
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
