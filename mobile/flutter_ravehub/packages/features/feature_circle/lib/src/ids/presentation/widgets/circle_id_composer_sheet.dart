import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// Bottom sheet for creating or editing a Circle ID card.
class CircleIdComposerSheet extends StatefulWidget {
  const CircleIdComposerSheet({
    super.key,
    required this.onSubmit,
    this.initialNickname,
    this.initialTagline,
    this.initialGradientIndex,
  });

  final Future<void> Function(
    String nickname,
    String tagline,
    int gradientIndex,
  ) onSubmit;
  final String? initialNickname;
  final String? initialTagline;
  final int? initialGradientIndex;

  @override
  State<CircleIdComposerSheet> createState() => _CircleIdComposerSheetState();
}

class _CircleIdComposerSheetState extends State<CircleIdComposerSheet> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _taglineController;
  int _selectedGradient = 0;
  bool _isSubmitting = false;

  static const _gradients = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    [Color(0xFFEC4899), Color(0xFFF43F5E)],
    [Color(0xFF14B8A6), Color(0xFF06B6D4)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    [Color(0xFF06B6D4), Color(0xFF3B82F6)],
  ];

  bool get _canSubmit =>
      _nicknameController.text.trim().isNotEmpty && !_isSubmitting;

  @override
  void initState() {
    super.initState();
    _nicknameController =
        TextEditingController(text: widget.initialNickname ?? '');
    _taglineController =
        TextEditingController(text: widget.initialTagline ?? '');
    _selectedGradient = widget.initialGradientIndex ?? 0;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    await widget.onSubmit(
      _nicknameController.text.trim(),
      _taglineController.text.trim(),
      _selectedGradient,
    );
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.initialNickname != null;

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
            // Handle
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
              isEditing
                  ? lt('编辑ID卡', 'Edit ID Card', 'IDカードを編集')
                  : lt('创建ID卡', 'Create ID Card', 'IDカードを作成'),
              style: RaverTypography.title(
                size: 20,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 20),

            // Preview card
            _buildPreview(theme),
            const SizedBox(height: 20),

            // Template selection
            Text(
              lt('选择模板', 'Choose Template', 'テンプレートを選択'),
              style: RaverTypography.label(
                size: 14,
                color: theme.primaryText,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _gradients.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = _selectedGradient == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedGradient = index),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _gradients[index],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _gradients[index]
                                      .first
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Nickname
            Text(
              lt('昵称', 'Nickname', 'ニックネーム'),
              style: RaverTypography.label(
                size: 14,
                color: theme.primaryText,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nicknameController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: lt(
                  '输入你的昵称',
                  'Enter your nickname',
                  'ニックネームを入力',
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

            // Tagline
            Text(
              lt('个人标语', 'Tagline', 'タグライン'),
              style: RaverTypography.label(
                size: 14,
                color: theme.primaryText,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _taglineController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: lt(
                  '一句话介绍自己',
                  'Describe yourself in one line',
                  '自己紹介を一行で',
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

            // Save button
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
                        lt('保存', 'Save', '保存'),
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

  Widget _buildPreview(RaverThemeData theme) {
    final gradientColors = _gradients[_selectedGradient];
    final nickname = _nicknameController.text.trim();
    final tagline = _taglineController.text.trim();

    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child:
                  const Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              nickname.isEmpty
                  ? lt('你的昵称', 'Your Nickname', 'あなたのニックネーム')
                  : nickname,
              style: RaverTypography.label(
                size: 18,
                color: Colors.white,
                weight: FontWeight.w700,
              ),
            ),
            if (tagline.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                tagline,
                style: RaverTypography.caption(
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Text(
              'CIRCLE ID',
              style: RaverTypography.caption(
                size: 9,
                color: Colors.white.withValues(alpha: 0.5),
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
