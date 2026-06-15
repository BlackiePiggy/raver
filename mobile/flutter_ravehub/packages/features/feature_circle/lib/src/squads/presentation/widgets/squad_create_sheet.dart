import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// Bottom sheet for creating a new squad.
class SquadCreateSheet extends StatefulWidget {
  const SquadCreateSheet({super.key, required this.onSubmit});

  final Future<void> Function(
    String name,
    String description,
    String? coverUrl,
  ) onSubmit;

  @override
  State<SquadCreateSheet> createState() => _SquadCreateSheetState();
}

class _SquadCreateSheetState extends State<SquadCreateSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSubmitting = false;

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty && !_isSubmitting;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    await widget.onSubmit(
      _nameController.text.trim(),
      _descController.text.trim(),
      null, // cover URL, would come from image picker
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
            // Handle bar
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
              lt('创建小队', 'Create Squad', 'スクワッドを作成'),
              style: RaverTypography.title(
                size: 20,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 20),

            // Cover upload placeholder
            GestureDetector(
              onTap: () {
                // TODO: Use MediaPickerService
              },
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.cardBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 32,
                      color: theme.secondaryText,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lt('上传封面', 'Upload Cover', 'カバーをアップロード'),
                      style: RaverTypography.caption(
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Name input
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
                hintText: lt('输入小队名称', 'Enter squad name', 'スクワッド名を入力'),
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

            // Description input
            Text(
              lt('简介', 'Description', '説明'),
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
                hintText: lt('介绍你的小队', 'Describe your squad', 'スクワッドの説明'),
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

            // Create button
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
