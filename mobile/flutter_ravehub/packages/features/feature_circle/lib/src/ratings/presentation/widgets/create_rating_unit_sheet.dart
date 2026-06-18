import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

/// Bottom sheet for creating a new rating unit within a rating event.
class CreateRatingUnitSheet extends StatefulWidget {
  const CreateRatingUnitSheet({
    super.key,
    required this.onSubmit,
    this.initialName = '',
    this.initialDescription = '',
    this.initialDjId = '',
    this.initialImageUrl = '',
    this.title,
    this.submitLabel,
    this.onUploadImage,
  });

  final Future<void> Function(
    String name,
    String description,
    String djId,
    String imageUrl,
  ) onSubmit;
  final String initialName;
  final String initialDescription;
  final String initialDjId;
  final String initialImageUrl;
  final String? title;
  final String? submitLabel;
  final Future<String> Function(String localPath)? onUploadImage;

  @override
  State<CreateRatingUnitSheet> createState() => _CreateRatingUnitSheetState();
}

class _CreateRatingUnitSheetState extends State<CreateRatingUnitSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _djIdController;
  late final TextEditingController _imageUrlController;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _djIdController.text.trim().isNotEmpty &&
      !_isUploadingImage &&
      !_isSubmitting;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descController = TextEditingController(text: widget.initialDescription);
    _djIdController = TextEditingController(text: widget.initialDjId);
    _imageUrlController = TextEditingController(text: widget.initialImageUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _djIdController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    await widget.onSubmit(
      _nameController.text.trim(),
      _descController.text.trim(),
      _djIdController.text.trim(),
      _imageUrlController.text.trim(),
    );
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _pickAndUploadImage() async {
    if (_isUploadingImage || widget.onUploadImage == null) return;
    final path = await MediaPickerService.pickImage();
    if (path == null) return;
    setState(() => _isUploadingImage = true);
    try {
      final url = await widget.onUploadImage!(path);
      if (!mounted) return;
      setState(() {
        _imageUrlController.text = url;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt(
              '图片上传失败，请稍后重试',
              'Image upload failed. Please try again.',
              '画像のアップロードに失敗しました。もう一度お試しください。',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
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
              widget.title ?? lt('创建评分单元', 'Create Rating Unit', '評価ユニットを作成'),
              style: RaverTypography.title(size: 20, color: theme.primaryText),
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
                hintText: lt('输入评分单元名称', 'Enter unit name', 'ユニット名を入力'),
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
                  '描述这个评分单元（选填）',
                  'Describe this unit (optional)',
                  'このユニットについて説明（任意）',
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

            // Image URL
            Text(
              lt('图片 URL', 'Image URL', '画像URL'),
              style: RaverTypography.label(
                size: 14,
                color: theme.primaryText,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _imageUrlController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: lt(
                  '输入图片 URL（选填）',
                  'Enter image URL (optional)',
                  '画像URLを入力（任意）',
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
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isUploadingImage ? null : _pickAndUploadImage,
              icon: _isUploadingImage
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined),
              label: Text(
                _imageUrlController.text.trim().isEmpty
                    ? lt('从相册上传图片', 'Upload Image from Gallery',
                        'ギャラリーから画像をアップロード')
                    : lt('重新上传图片', 'Replace Image', '画像を再アップロード'),
              ),
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
                hintText: lt('输入DJ ID', 'Enter DJ ID', 'DJ IDを入力'),
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
                        widget.submitLabel ?? lt('创建', 'Create', '作成'),
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
