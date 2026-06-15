import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// Bottom sheet for creating a new rating event.
class CreateRatingEventSheet extends StatefulWidget {
  const CreateRatingEventSheet({super.key, required this.onSubmit});

  final Future<void> Function(
    String name,
    String description,
    String eventId,
  ) onSubmit;

  @override
  State<CreateRatingEventSheet> createState() =>
      _CreateRatingEventSheetState();
}

class _CreateRatingEventSheetState extends State<CreateRatingEventSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _eventIdController = TextEditingController();
  bool _isSubmitting = false;

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _eventIdController.text.trim().isNotEmpty &&
      !_isSubmitting;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _eventIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    await widget.onSubmit(
      _nameController.text.trim(),
      _descController.text.trim(),
      _eventIdController.text.trim(),
    );
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              lt('创建评分活动', 'Create Rating Event', '評価イベントを作成'),
              style: RaverTypography.title(
                size: 20,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 20),

            // Name
            Text(
              lt('名称', 'Name', '名前'),
              style: RaverTypography.label(
                size: 14,
                color: theme.primaryText,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: lt(
                  '输入评分活动名称',
                  'Enter rating event name',
                  '評価イベント名を入力',
                ),
                hintStyle: RaverTypography.body(
                  size: 15,
                  color: theme.secondaryText,
                ),
                filled: true,
                fillColor: theme.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
              ),
              style: RaverTypography.body(size: 15, color: theme.primaryText),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              lt('描述', 'Description', '説明'),
              style: RaverTypography.label(
                size: 14,
                color: theme.primaryText,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: lt(
                  '描述这个评分活动',
                  'Describe this rating event',
                  'この評価イベントについて説明',
                ),
                hintStyle: RaverTypography.body(
                  size: 15,
                  color: theme.secondaryText,
                ),
                filled: true,
                fillColor: theme.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
              ),
              style: RaverTypography.body(size: 15, color: theme.primaryText),
            ),
            const SizedBox(height: 16),

            // Event ID
            Text(
              lt('关联活动', 'Associated Event', '関連イベント'),
              style: RaverTypography.label(
                size: 14,
                color: theme.primaryText,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _eventIdController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: lt(
                  '输入活动ID',
                  'Enter event ID',
                  'イベントIDを入力',
                ),
                hintStyle: RaverTypography.body(
                  size: 15,
                  color: theme.secondaryText,
                ),
                filled: true,
                fillColor: theme.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
              ),
              style: RaverTypography.body(size: 15, color: theme.primaryText),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  disabledBackgroundColor: theme.accent.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        lt('创建', 'Create', '作成'),
                        style: RaverTypography.label(
                          size: 16,
                          color: Colors.white,
                          weight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}
