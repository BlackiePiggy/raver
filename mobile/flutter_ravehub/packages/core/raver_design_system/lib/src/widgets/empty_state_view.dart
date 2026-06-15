import 'package:flutter/material.dart';

import '../theme/raver_theme.dart';
import '../theme/raver_typography.dart';

/// A full-width empty-state placeholder view.
///
/// Displays an icon, a title, an optional subtitle, and an optional action
/// button. Used when a list or screen has no content to display.
class EmptyStateView extends StatelessWidget {
  /// Creates an [EmptyStateView].
  const EmptyStateView({
    super.key,
    this.icon = Icons.inbox_outlined,
    this.title = 'Nothing here yet',
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconSize = 56,
  });

  /// The icon displayed above the title.
  final IconData icon;

  /// Primary message.
  final String title;

  /// Optional secondary message.
  final String? subtitle;

  /// Label for the optional action button.
  final String? actionLabel;

  /// Callback for the action button.
  final VoidCallback? onAction;

  /// Size of the icon.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: theme.secondaryText.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: RaverTypography.title(color: theme.primaryText),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: RaverTypography.body(
                  size: 14,
                  color: theme.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: theme.accent,
                  textStyle: RaverTypography.label(),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
