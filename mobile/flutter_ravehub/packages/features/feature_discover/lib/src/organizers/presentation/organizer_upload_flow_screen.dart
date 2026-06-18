import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

import '../data/organizer_api.dart';
import '../../_shared/discover_service_locator.dart';
import 'view_models/organizer_upload_view_model.dart';

/// A 4-step wizard for uploading a new organizer/festival entry.
class OrganizerUploadFlowScreen extends StatefulWidget {
  const OrganizerUploadFlowScreen({super.key});

  @override
  State<OrganizerUploadFlowScreen> createState() =>
      _OrganizerUploadFlowScreenState();
}

class _OrganizerUploadFlowScreenState extends State<OrganizerUploadFlowScreen> {
  late final OrganizerUploadViewModel _vm;
  final MediaPickerService _mediaPicker = MediaPickerService();

  // Controllers for text fields
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _websiteController = TextEditingController();
  final _foundingYearController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm = OrganizerUploadViewModel(
      api: OrganizerApi(DiscoverServiceLocator.dio),
    );
    _vm.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onViewModelChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _websiteController.dispose();
    _foundingYearController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadCover() async {
    final path = await _mediaPicker.pickImageInstance();
    if (path != null) {
      await _vm.uploadCover(path);
    }
  }

  Future<void> _onSubmit() async {
    final success = await _vm.submit();
    if (success && mounted) {
      context.pop(true);
    } else if (!success && _vm.errorMessage != null && mounted) {
      ToastBanner.show(
        context,
        message: _vm.errorMessage!,
        type: ToastType.error,
      );
    }
  }

  void _showAddDialog({
    required String title,
    required ValueChanged<String> onAdd,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = ctx.raver;
        return AlertDialog(
          backgroundColor: theme.card,
          title: Text(title, style: RaverTypography.title(color: theme.primaryText)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: RaverTypography.body(color: theme.primaryText),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(lt('取消', 'Cancel', 'キャンセル')),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  onAdd(controller.text.trim());
                }
                Navigator.of(ctx).pop();
              },
              child: Text(lt('添加', 'Add', '追加')),
            ),
          ],
        );
      },
    );
    // Dispose controller after dialog is closed
    // (Flutter disposes it when AlertDialog is removed from tree)
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          lt('提交音乐节', 'Submit Festival', 'フェスを投稿'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_vm.currentStepIndex + 1) / _vm.totalSteps,
            backgroundColor: theme.cardBorder,
            valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepContent(theme),
            ),
          ),
          _buildBottomNav(theme),
        ],
      ),
    );
  }

  Widget _buildStepContent(RaverThemeData theme) {
    return switch (_vm.currentStep) {
      OrganizerUploadStep.basicInfo => _buildBasicInfoStep(theme),
      OrganizerUploadStep.media => _buildMediaStep(theme),
      OrganizerUploadStep.details => _buildDetailsStep(theme),
      OrganizerUploadStep.submit => _buildSubmitStep(theme),
    };
  }

  // ---------------------------------------------------------------------------
  // Step 0: Basic Info
  // ---------------------------------------------------------------------------

  Widget _buildBasicInfoStep(RaverThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lt('基本信息', 'Basic Information', '基本情報'),
          style: RaverTypography.title(size: 18, color: theme.primaryText),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          onChanged: _vm.setName,
          style: RaverTypography.body(color: theme.primaryText),
          decoration: _inputDecoration(
            theme,
            label: lt('名称 *', 'Name *', '名前 *'),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          onChanged: _vm.setDescription,
          minLines: 3,
          maxLines: 5,
          style: RaverTypography.body(color: theme.primaryText),
          decoration: _inputDecoration(
            theme,
            label: lt('简介', 'Description', '説明'),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _countryController,
          onChanged: _vm.setCountry,
          style: RaverTypography.body(color: theme.primaryText),
          decoration: _inputDecoration(
            theme,
            label: lt('国家', 'Country', '国'),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _cityController,
          onChanged: _vm.setCity,
          style: RaverTypography.body(color: theme.primaryText),
          decoration: _inputDecoration(
            theme,
            label: lt('城市', 'City', '都市'),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _websiteController,
          onChanged: _vm.setWebsite,
          keyboardType: TextInputType.url,
          style: RaverTypography.body(color: theme.primaryText),
          decoration: _inputDecoration(
            theme,
            label: lt('官网', 'Website', 'ウェブサイト'),
            hint: 'https://',
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Media
  // ---------------------------------------------------------------------------

  Widget _buildMediaStep(RaverThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lt('封面图片', 'Cover Image', 'カバー画像'),
          style: RaverTypography.title(size: 18, color: theme.primaryText),
        ),
        const SizedBox(height: 16),
        _buildCoverUploadArea(theme),
      ],
    );
  }

  Widget _buildCoverUploadArea(RaverThemeData theme) {
    if (_vm.coverImageUrl != null && _vm.coverImageUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: _pickAndUploadCover,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 400,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RemoteCoverImage(
                  url: _vm.coverImageUrl!,
                  height: 400,
                  borderRadius: BorderRadius.circular(12),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          lt('更换', 'Change', '変更'),
                          style: RaverTypography.label(
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _vm.isLoading ? null : _pickAndUploadCover,
      child: Container(
        height: 400,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.cardBorder,
            width: 1.5,
          ),
          color: theme.card.withValues(alpha: 0.3),
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: theme.cardBorder),
          child: _vm.isLoading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 56,
                      color: theme.secondaryText,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lt(
                        '点击上传封面图片',
                        'Tap to upload cover image',
                        'タップしてカバー画像をアップロード',
                      ),
                      style: RaverTypography.label(
                        size: 15,
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Details
  // ---------------------------------------------------------------------------

  Widget _buildDetailsStep(RaverThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lt('详细信息', 'Details', '詳細情報'),
          style: RaverTypography.title(size: 18, color: theme.primaryText),
        ),
        const SizedBox(height: 16),

        // Founding year
        TextFormField(
          controller: _foundingYearController,
          onChanged: (v) => _vm.setFoundingYear(int.tryParse(v)),
          keyboardType: TextInputType.number,
          style: RaverTypography.body(color: theme.primaryText),
          decoration: _inputDecoration(
            theme,
            label: lt('创立年份', 'Founding Year', '設立年'),
            hint: 'e.g. 2015',
          ),
        ),
        const SizedBox(height: 20),

        // Genres
        Text(
          lt('流派', 'Genres', 'ジャンル'),
          style: RaverTypography.title(size: 15, color: theme.primaryText),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._vm.genres.asMap().entries.map(
                  (entry) => Chip(
                    label: Text(entry.value),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _vm.removeGenre(entry.key),
                    backgroundColor: theme.card,
                    side: BorderSide(color: theme.cardBorder),
                  ),
                ),
            ActionChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: theme.accent),
                  const SizedBox(width: 4),
                  Text(
                    lt('添加流派', 'Add Genre', 'ジャンルを追加'),
                    style: RaverTypography.label(
                      size: 13,
                      color: theme.accent,
                    ),
                  ),
                ],
              ),
              onPressed: () => _showAddDialog(
                title: lt('添加流派', 'Add Genre', 'ジャンルを追加'),
                onAdd: _vm.addGenre,
              ),
              backgroundColor: theme.card,
              side: BorderSide(color: theme.accent.withValues(alpha: 0.3)),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Aliases
        Text(
          lt('别名', 'Aliases', '別名'),
          style: RaverTypography.title(size: 15, color: theme.primaryText),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._vm.aliases.asMap().entries.map(
                  (entry) => Chip(
                    label: Text(entry.value),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _vm.removeAlias(entry.key),
                    backgroundColor: theme.card,
                    side: BorderSide(color: theme.cardBorder),
                  ),
                ),
            ActionChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: theme.accent),
                  const SizedBox(width: 4),
                  Text(
                    lt('添加别名', 'Add Alias', '別名を追加'),
                    style: RaverTypography.label(
                      size: 13,
                      color: theme.accent,
                    ),
                  ),
                ],
              ),
              onPressed: () => _showAddDialog(
                title: lt('添加别名', 'Add Alias', '別名を追加'),
                onAdd: _vm.addAlias,
              ),
              backgroundColor: theme.card,
              side: BorderSide(color: theme.accent.withValues(alpha: 0.3)),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Submit (Review)
  // ---------------------------------------------------------------------------

  Widget _buildSubmitStep(RaverThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lt('确认提交', 'Review & Submit', '確認して送信'),
          style: RaverTypography.title(size: 18, color: theme.primaryText),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reviewRow(
                theme,
                label: lt('名称', 'Name', '名前'),
                value: _vm.name,
              ),
              if (_vm.description.isNotEmpty)
                _reviewRow(
                  theme,
                  label: lt('简介', 'Description', '説明'),
                  value: _vm.description,
                ),
              if (_vm.country.isNotEmpty)
                _reviewRow(
                  theme,
                  label: lt('国家', 'Country', '国'),
                  value: _vm.country,
                ),
              if (_vm.city.isNotEmpty)
                _reviewRow(
                  theme,
                  label: lt('城市', 'City', '都市'),
                  value: _vm.city,
                ),
              if (_vm.website.isNotEmpty)
                _reviewRow(
                  theme,
                  label: lt('官网', 'Website', 'ウェブサイト'),
                  value: _vm.website,
                ),
              if (_vm.coverImageUrl != null)
                _reviewRow(
                  theme,
                  label: lt('封面', 'Cover', 'カバー'),
                  value: lt('已上传', 'Uploaded', 'アップロード済み'),
                ),
              if (_vm.foundingYear != null)
                _reviewRow(
                  theme,
                  label: lt('创立年份', 'Founding Year', '設立年'),
                  value: '${_vm.foundingYear}',
                ),
              if (_vm.genres.isNotEmpty)
                _reviewRow(
                  theme,
                  label: lt('流派', 'Genres', 'ジャンル'),
                  value: _vm.genres.join(', '),
                ),
              if (_vm.aliases.isNotEmpty)
                _reviewRow(
                  theme,
                  label: lt('别名', 'Aliases', '別名'),
                  value: _vm.aliases.join(', '),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: lt('提交', 'Submit', '送信'),
          onPressed: _vm.isLoading ? null : _onSubmit,
          isLoading: _vm.isLoading,
          isExpanded: true,
        ),
        if (_vm.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _vm.errorMessage!,
            style: RaverTypography.caption(color: Colors.red),
          ),
        ],
      ],
    );
  }

  Widget _reviewRow(
    RaverThemeData theme, {
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: RaverTypography.label(
                size: 13,
                color: theme.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: RaverTypography.body(
                size: 14,
                color: theme.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom navigation
  // ---------------------------------------------------------------------------

  Widget _buildBottomNav(RaverThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(
          top: BorderSide(color: theme.cardBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (!_vm.isFirstStep)
            Expanded(
              child: OutlinedButton(
                onPressed: _vm.prevStep,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  lt('上一步', 'Back', '戻る'),
                  style: RaverTypography.label(color: theme.primaryText),
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 12),
          if (!_vm.isLastStep)
            Expanded(
              child: ElevatedButton(
                onPressed: _vm.currentStep == OrganizerUploadStep.basicInfo &&
                        !_vm.canProceedFromBasicInfo
                    ? null
                    : _vm.nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  lt('下一步', 'Next', '次へ'),
                  style: RaverTypography.label(color: Colors.white),
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    RaverThemeData theme, {
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: RaverTypography.label(color: theme.secondaryText),
      hintStyle: RaverTypography.body(
        color: theme.secondaryText.withValues(alpha: 0.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: theme.cardBorder),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

/// Paints a dashed rectangular border.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 4.0;
    final rrect = RRect.fromLTRBR(
      0,
      0,
      size.width,
      size.height,
      const Radius.circular(12),
    );

    final path = Path()..addRRect(rrect);
    final dashPath = Path();

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        dashPath.addPath(
          metric.extractPath(distance, end),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}
