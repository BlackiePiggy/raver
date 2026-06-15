import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../data/dj_api.dart';
import 'view_models/dj_editor_view_model.dart';
import '../../_shared/discover_service_locator.dart';

/// Three-step wizard for uploading a new DJ profile:
///   Step 1 — Source (manual entry / Spotify import / Discogs import)
///   Step 2 — Core info (name, bio, nationality, genres)
///   Step 3 — Links & avatar (social links, profile photo)
///
/// On completion navigates to the newly created DJ's detail page.
class DjUploadFlowScreen extends StatefulWidget {
  const DjUploadFlowScreen({super.key});

  @override
  State<DjUploadFlowScreen> createState() => _DjUploadFlowScreenState();
}

class _DjUploadFlowScreenState extends State<DjUploadFlowScreen> {
  int _step = 0; // 0: source, 1: info, 2: links
  _DJSource _source = _DJSource.manual;
  late final DjEditorViewModel _vm;
  late final DjApi _djApi;

  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _spotifyCtrl = TextEditingController();
  final _soundcloudCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _spotifyIdCtrl = TextEditingController();
  final _discogsIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _djApi = DiscoverServiceLocator.djApi;
    _vm = DjEditorViewModel(djApi: _djApi);
    _vm.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_rebuild);
    _vm.dispose();
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _nationalityCtrl.dispose();
    _spotifyCtrl.dispose();
    _soundcloudCtrl.dispose();
    _instagramCtrl.dispose();
    _spotifyIdCtrl.dispose();
    _discogsIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _vm
      ..setDisplayName(_nameCtrl.text.trim())
      ..setBio(_bioCtrl.text.trim())
      ..setNationality(_nationalityCtrl.text.trim())
      ..setSpotifyUrl(_spotifyCtrl.text.trim())
      ..setSoundcloudUrl(_soundcloudCtrl.text.trim())
      ..setInstagramUrl(_instagramCtrl.text.trim());

    await _vm.save();
    if (_vm.isSaved && _vm.djId != null && mounted) {
      context.go('/djs/${_vm.djId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        title: Text(
          lt('上传 DJ', 'Upload DJ', 'DJをアップロード'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.primaryText),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(currentStep: _step, totalSteps: 3),
          Expanded(
            child: switch (_step) {
              0 => _SourceStep(
                  selected: _source,
                  onChanged: (s) => setState(() => _source = s),
                  spotifyIdCtrl: _spotifyIdCtrl,
                  discogsIdCtrl: _discogsIdCtrl,
                ),
              1 => _InfoStep(
                  nameCtrl: _nameCtrl,
                  bioCtrl: _bioCtrl,
                  nationalityCtrl: _nationalityCtrl,
                ),
              _ => _LinksStep(
                  spotifyCtrl: _spotifyCtrl,
                  soundcloudCtrl: _soundcloudCtrl,
                  instagramCtrl: _instagramCtrl,
                  vm: _vm,
                ),
            },
          ),
          _BottomNav(
            step: _step,
            totalSteps: 3,
            isSubmitting: _vm.isLoading,
            onBack: _step > 0 ? () => setState(() => _step--) : null,
            onNext: _step < 2
                ? () => setState(() => _step++)
                : _submit,
          ),
        ],
      ),
    );
  }
}

enum _DJSource { manual, spotify, discogs }

// ---------------------------------------------------------------------------
// Step widgets
// ---------------------------------------------------------------------------

class _SourceStep extends StatelessWidget {
  const _SourceStep({
    required this.selected,
    required this.onChanged,
    required this.spotifyIdCtrl,
    required this.discogsIdCtrl,
  });

  final _DJSource selected;
  final ValueChanged<_DJSource> onChanged;
  final TextEditingController spotifyIdCtrl;
  final TextEditingController discogsIdCtrl;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          lt('选择导入来源', 'Choose Import Source', 'インポート元を選択'),
          style: RaverTypography.headlineSmall(color: theme.primaryText),
        ),
        const SizedBox(height: 24),
        _SourceOption(
          icon: Icons.person_outline,
          title: lt('手动填写', 'Manual Entry', '手動入力'),
          subtitle: lt('自己填写 DJ 信息', 'Fill in DJ info yourself', '自分でDJ情報を入力'),
          isSelected: selected == _DJSource.manual,
          onTap: () => onChanged(_DJSource.manual),
        ),
        _SourceOption(
          icon: Icons.music_note,
          title: 'Spotify',
          subtitle: lt('从 Spotify Artist ID 导入', 'Import from Spotify Artist ID', 'Spotify Artist IDからインポート'),
          isSelected: selected == _DJSource.spotify,
          onTap: () => onChanged(_DJSource.spotify),
        ),
        if (selected == _DJSource.spotify)
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
            child: TextField(
              controller: spotifyIdCtrl,
              style: TextStyle(color: theme.primaryText),
              decoration: InputDecoration(
                labelText: 'Spotify Artist ID',
                labelStyle: TextStyle(color: theme.secondaryText),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.divider),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF8B5CF6)),
                ),
              ),
            ),
          ),
        _SourceOption(
          icon: Icons.album_outlined,
          title: 'Discogs',
          subtitle: lt('从 Discogs Artist ID 导入', 'Import from Discogs Artist ID', 'Discogs Artist IDからインポート'),
          isSelected: selected == _DJSource.discogs,
          onTap: () => onChanged(_DJSource.discogs),
        ),
        if (selected == _DJSource.discogs)
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
            child: TextField(
              controller: discogsIdCtrl,
              style: TextStyle(color: theme.primaryText),
              decoration: InputDecoration(
                labelText: 'Discogs Artist ID',
                labelStyle: TextStyle(color: theme.secondaryText),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.divider),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF8B5CF6)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : theme.divider,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? const Color(0xFF8B5CF6).withAlpha(26)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? const Color(0xFF8B5CF6) : theme.secondaryText),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: RaverTypography.bodyMedium(
                          color: theme.primaryText,
                          weight: FontWeight.w600)),
                  Text(subtitle,
                      style: RaverTypography.caption(color: theme.secondaryText)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF8B5CF6)),
          ],
        ),
      ),
    );
  }
}

class _InfoStep extends StatelessWidget {
  const _InfoStep({
    required this.nameCtrl,
    required this.bioCtrl,
    required this.nationalityCtrl,
  });

  final TextEditingController nameCtrl;
  final TextEditingController bioCtrl;
  final TextEditingController nationalityCtrl;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          lt('DJ 信息', 'DJ Info', 'DJ情報'),
          style: RaverTypography.headlineSmall(color: theme.primaryText),
        ),
        const SizedBox(height: 24),
        _Field(
          ctrl: nameCtrl,
          label: lt('DJ 名', 'DJ Name', 'DJ名'),
          required: true,
        ),
        const SizedBox(height: 16),
        _Field(
          ctrl: bioCtrl,
          label: lt('简介', 'Bio', '自己紹介'),
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        _Field(
          ctrl: nationalityCtrl,
          label: lt('国籍', 'Nationality', '国籍'),
        ),
      ],
    );
  }
}

class _LinksStep extends StatelessWidget {
  const _LinksStep({
    required this.spotifyCtrl,
    required this.soundcloudCtrl,
    required this.instagramCtrl,
    required this.vm,
  });

  final TextEditingController spotifyCtrl;
  final TextEditingController soundcloudCtrl;
  final TextEditingController instagramCtrl;
  final DjEditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          lt('社交链接', 'Social Links', 'ソーシャルリンク'),
          style: RaverTypography.headlineSmall(color: theme.primaryText),
        ),
        const SizedBox(height: 24),
        _Field(ctrl: spotifyCtrl, label: 'Spotify URL'),
        const SizedBox(height: 16),
        _Field(ctrl: soundcloudCtrl, label: 'SoundCloud URL'),
        const SizedBox(height: 16),
        _Field(ctrl: instagramCtrl, label: 'Instagram URL'),
        if (vm.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            vm.errorMessage!,
            style: RaverTypography.caption(color: Colors.red),
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    this.maxLines = 1,
    this.required = false,
  });

  final TextEditingController ctrl;
  final String label;
  final int maxLines;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(color: theme.primaryText),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: TextStyle(color: theme.secondaryText),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.divider),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF8B5CF6)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step indicator + bottom nav
// ---------------------------------------------------------------------------

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.totalSteps});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(totalSteps, (i) {
          final active = i <= currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < totalSteps - 1 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF8B5CF6)
                    : theme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.step,
    required this.totalSteps,
    required this.isSubmitting,
    required this.onNext,
    this.onBack,
  });

  final int step;
  final int totalSteps;
  final bool isSubmitting;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isLast = step == totalSteps - 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Row(
          children: [
            if (onBack != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    lt('上一步', 'Back', '前へ'),
                    style: const TextStyle(color: Color(0xFF8B5CF6)),
                  ),
                ),
              ),
            if (onBack != null) const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                onTap: isSubmitting ? null : onNext,
                label: isLast
                    ? (isSubmitting
                        ? lt('提交中...', 'Submitting...', '送信中...')
                        : lt('提交', 'Submit', '送信'))
                    : lt('下一步', 'Next', '次へ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
