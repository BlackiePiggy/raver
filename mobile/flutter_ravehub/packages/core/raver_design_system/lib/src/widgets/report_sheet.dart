import 'package:flutter/material.dart';

import '../theme/raver_theme.dart';
import '../theme/raver_typography.dart';

/// Reason categories for content reporting.
enum ReportReason {
  spam('Spam or scam'),
  harassment('Harassment or bullying'),
  hateSpeech('Hate speech'),
  violence('Violence or threats'),
  nudity('Nudity or sexual content'),
  misinformation('False information'),
  impersonation('Impersonation'),
  other('Other');

  const ReportReason(this.label);
  final String label;
}

/// A modal bottom sheet for reporting content.
///
/// Presents a list of report reasons and an optional free-text field for
/// additional context, then calls [onSubmit] with the selected reason and
/// optional details.
class ReportSheet extends StatefulWidget {
  /// Creates a [ReportSheet].
  const ReportSheet({
    required this.onSubmit,
    super.key,
    this.contentType = 'content',
  });

  /// Called when the user submits the report.
  final void Function(ReportReason reason, String? details) onSubmit;

  /// Description of the content being reported (e.g. "post", "comment").
  final String contentType;

  /// Shows the [ReportSheet] as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required void Function(ReportReason reason, String? details) onSubmit,
    String contentType = 'content',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportSheet(
        onSubmit: onSubmit,
        contentType: contentType,
      ),
    );
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  ReportReason? _selectedReason;
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedReason == null) return;
    final details = _detailsController.text.trim();
    widget.onSubmit(
      _selectedReason!,
      details.isNotEmpty ? details : null,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.secondaryText.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Report ${widget.contentType}',
                style: RaverTypography.title(color: theme.primaryText),
              ),
              const SizedBox(height: 4),
              Text(
                'Why are you reporting this ${widget.contentType}?',
                style: RaverTypography.body(
                  size: 14,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 16),

              // Reason list
              ...ReportReason.values.map((reason) {
                final isSelected = _selectedReason == reason;
                return GestureDetector(
                  onTap: () => setState(() => _selectedReason = reason),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isSelected ? theme.accent : theme.cardBorder,
                              width: isSelected ? 6 : 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          reason.label,
                          style: RaverTypography.body(
                            size: 15,
                            color: theme.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Additional details
              if (_selectedReason != null) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _detailsController,
                  maxLines: 3,
                  style: RaverTypography.body(
                    size: 14,
                    color: theme.primaryText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Additional details (optional)',
                    hintStyle: RaverTypography.body(
                      size: 14,
                      color: theme.secondaryText,
                    ),
                    filled: true,
                    fillColor: theme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.accent),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedReason != null ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        theme.accent.withValues(alpha: 0.3),
                    disabledForegroundColor: Colors.white60,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    textStyle: RaverTypography.label(size: 15),
                  ),
                  child: const Text('Submit Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
