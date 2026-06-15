import 'package:flutter/material.dart';

import '../theme/raver_theme.dart';
import '../theme/raver_typography.dart';

/// A full-width error-state placeholder view.
///
/// Displays an error icon, a title, an optional description, and a retry
/// button.
class ErrorStateView extends StatelessWidget {
  /// Creates an [ErrorStateView].
  const ErrorStateView({
    super.key,
    this.title = 'Something went wrong',
    this.description,
    this.error,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  /// Primary error message.
  final String title;

  /// Optional detailed description.
  final String? description;

  /// The underlying error object, whose `toString()` is shown if
  /// [description] is null.
  final Object? error;

  /// Callback when the retry button is tapped.
  final VoidCallback? onRetry;

  /// Label for the retry button.
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    final displayDescription =
        description ?? (error != null ? error.toString() : null);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: theme.secondaryText.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: RaverTypography.title(color: theme.primaryText),
              textAlign: TextAlign.center,
            ),
            if (displayDescription != null) ...[
              const SizedBox(height: 8),
              Text(
                displayDescription,
                style: RaverTypography.body(
                  size: 14,
                  color: theme.secondaryText,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.accent,
                  side: BorderSide(color: theme.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: RaverTypography.label(),
                ),
                child: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
