import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/raver_motion.dart';
import '../theme/raver_theme.dart';
import '../theme/raver_typography.dart';

/// The visual style of a [ToastBanner].
enum ToastType {
  /// Green success toast.
  success,

  /// Red error toast.
  error,

  /// Blue informational toast.
  info,
}

/// An animated toast banner for operation feedback.
///
/// Use [ToastBanner.show] to display a toast from anywhere.
class ToastBanner extends StatefulWidget {
  /// Creates a [ToastBanner].
  const ToastBanner({
    required this.message,
    super.key,
    this.type = ToastType.info,
    this.duration = const Duration(seconds: 3),
    this.onDismiss,
  });

  /// The message to display.
  final String message;

  /// Visual style.
  final ToastType type;

  /// How long the toast remains visible before auto-dismissing.
  final Duration duration;

  /// Called when the toast finishes dismissing.
  final VoidCallback? onDismiss;

  /// Shows a [ToastBanner] as an overlay entry.
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _ToastOverlay(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  @override
  State<ToastBanner> createState() => _ToastBannerState();
}

class _ToastBannerState extends State<ToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: RaverMotion.normal,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: RaverMotion.decelerate,
    ));
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();

    Future<void>.delayed(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _backgroundColor(RaverThemeData theme) {
    return switch (widget.type) {
      ToastType.success => const Color(0xFF1B9E5C),
      ToastType.error => const Color(0xFFD93636),
      ToastType.info => theme.accent,
    };
  }

  IconData _icon() {
    return switch (widget.type) {
      ToastType.success => Icons.check_circle_outline,
      ToastType.error => Icons.error_outline,
      ToastType.info => Icons.info_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _backgroundColor(theme),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _backgroundColor(theme).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(_icon(), color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.message,
                  style: RaverTypography.body(
                    size: 14,
                    color: Colors.white,
                    weight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: _dismiss,
                child: const Icon(
                  Icons.close,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Internal overlay wrapper that positions the toast at the top of the screen.
class _ToastOverlay extends StatelessWidget {
  const _ToastOverlay({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: ToastBanner(
          message: message,
          type: type,
          duration: duration,
          onDismiss: onDismiss,
        ),
      ),
    );
  }
}
