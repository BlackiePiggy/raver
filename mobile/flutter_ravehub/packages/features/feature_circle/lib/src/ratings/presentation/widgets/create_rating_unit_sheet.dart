import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// Bottom sheet for creating a new rating unit within a rating event.
class CreateRatingUnitSheet extends StatefulWidget {
  const CreateRatingUnitSheet({super.key, required this.onSubmit});

  final Future<void> Function(String name, String djId) onSubmit;

  @override
  State<CreateRatingUnitSheet> createState() => _CreateRatingUnitSheetState();
}

class _CreateRatingUnitSheetState extends State<CreateRatingUnitSheet> {
  final _nameController = TextEditingController();
  final _djIdController = TextEditingController();
  bool _isSubmitting = false;

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _djIdController.text.trim().isNotEmpty &&
      !_isSubmitting;

  @override
  void dispose() {
    _nameController.dispose();
    _djIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    await widget.onSubmit(
      _nameController.text.trim(),
      _djIdController.text.trim(),
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
              lt('创建评分单元', 'Create Rating Unit', '評価ユニットを作成'),
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
                  '输入评分单元名称',
                  'Enter unit name',
                  'ユニット名を入力',
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

            // DJ ID
            Text(
              lt('DJ', 'DJ', 'DJ'),
              style: RaverTypography.label(
                size: 14,
                color: theme.primaryText,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _djIdController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: lt(
                  '输入DJ ID',
                  'Enter DJ ID',
                  'DJ IDを入力',
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
