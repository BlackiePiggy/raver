import 'dart:async';

import 'package:flutter/material.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../theme/raver_theme.dart';
import '../theme/raver_typography.dart';

/// Reason categories for content reporting.
enum ReportReason {
  spam('spam'),
  harassment('harassment'),
  hateOrDiscrimination('hate_or_discrimination'),
  sexualContent('sexual_content'),
  violenceOrThreat('violence_or_threat'),
  illegalActivity('illegal_activity'),
  impersonation('impersonation'),
  privacyViolation('privacy_violation'),
  copyright('copyright'),
  scamOrFraud('scam_or_fraud'),
  minorSafety('minor_safety'),
  platformAbuse('platform_abuse'),
  other('other');

  const ReportReason(this.value);
  final String value;

  String get label => switch (this) {
    ReportReason.spam => lt('垃圾信息/刷屏', 'Spam or flooding', 'スパム/連投'),
    ReportReason.harassment => lt(
      '骚扰、辱骂或霸凌',
      'Harassment or bullying',
      '嫌がらせ、侮辱、いじめ',
    ),
    ReportReason.hateOrDiscrimination => lt(
      '仇恨或歧视',
      'Hate or discrimination',
      'ヘイトまたは差別',
    ),
    ReportReason.sexualContent => lt('色情或露骨内容', 'Sexual content', '性的または露骨な内容'),
    ReportReason.violenceOrThreat => lt('暴力威胁', 'Violence or threats', '暴力や脅迫'),
    ReportReason.illegalActivity => lt('违法活动', 'Illegal activity', '違法行為'),
    ReportReason.impersonation => lt('冒充他人', 'Impersonation', 'なりすまし'),
    ReportReason.privacyViolation => lt(
      '泄露隐私',
      'Privacy violation',
      'プライバシー侵害',
    ),
    ReportReason.copyright => lt('版权侵权', 'Copyright infringement', '著作権侵害'),
    ReportReason.scamOrFraud => lt('诈骗或钓鱼', 'Scam or fraud', '詐欺またはフィッシング'),
    ReportReason.minorSafety => lt('未成年人安全', 'Minor safety', '未成年者の安全'),
    ReportReason.platformAbuse => lt('平台滥用', 'Platform abuse', 'プラットフォーム悪用'),
    ReportReason.other => lt('其他', 'Other', 'その他'),
  };
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
  final FutureOr<void> Function(ReportReason reason, String? details) onSubmit;

  /// Description of the content being reported (e.g. "post", "comment").
  final String contentType;

  /// Shows the [ReportSheet] as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required FutureOr<void> Function(ReportReason reason, String? details)
    onSubmit,
    String contentType = 'content',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportSheet(onSubmit: onSubmit, contentType: contentType),
    );
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  ReportReason? _selectedReason;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null || _isSubmitting) return;
    final details = _detailsController.text.trim();
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await widget.onSubmit(
        _selectedReason!,
        details.isNotEmpty ? details : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = lt(
          '提交失败，请稍后重试。',
          'Submit failed. Please try again.',
          '送信に失敗しました。もう一度お試しください。',
        );
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
                lt(
                  '举报${widget.contentType}',
                  'Report ${widget.contentType}',
                  '${widget.contentType}を報告',
                ),
                style: RaverTypography.title(color: theme.primaryText),
              ),
              const SizedBox(height: 4),
              Text(
                lt(
                  '请选择举报原因，必要时补充说明。',
                  'Choose a reason and add details if needed.',
                  '理由を選択し、必要に応じて詳細を追加してください。',
                ),
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
                              color: isSelected
                                  ? theme.accent
                                  : theme.cardBorder,
                              width: isSelected ? 6 : 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            reason.label,
                            style: RaverTypography.body(
                              size: 15,
                              color: theme.primaryText,
                            ),
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
                    hintText: lt(
                      '补充说明（可选）',
                      'Additional details (optional)',
                      '補足説明（任意）',
                    ),
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
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: RaverTypography.caption(
                    color: Colors.redAccent,
                    weight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedReason != null && !_isSubmitting
                      ? _submit
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: theme.accent.withValues(
                      alpha: 0.3,
                    ),
                    disabledForegroundColor: Colors.white60,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    textStyle: RaverTypography.label(size: 15),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(lt('提交举报', 'Submit Report', '報告を送信')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
