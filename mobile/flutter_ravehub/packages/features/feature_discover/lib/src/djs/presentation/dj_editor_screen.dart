import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

import '../data/dj_api.dart';
import 'view_models/dj_editor_view_model.dart';

/// Create or edit a DJ profile.
///
/// Pass [djId] to load an existing DJ for editing. When `null` the screen
/// operates in creation mode.
class DjEditorScreen extends StatefulWidget {
  const DjEditorScreen({
    super.key,
    this.djId,
    required this.djApi,
  });

  final String? djId;
  final DjApi djApi;

  @override
  State<DjEditorScreen> createState() => _DjEditorScreenState();
}

class _DjEditorScreenState extends State<DjEditorScreen> {
  late final DjEditorViewModel _vm;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _nationalityCtrl;
  late final TextEditingController _spotifyCtrl;
  late final TextEditingController _soundcloudCtrl;
  late final TextEditingController _instagramCtrl;
  final _mediaPicker = MediaPickerService();

  @override
  void initState() {
    super.initState();
    _vm = DjEditorViewModel(djApi: widget.djApi);
    _nameCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _nationalityCtrl = TextEditingController();
    _spotifyCtrl = TextEditingController();
    _soundcloudCtrl = TextEditingController();
    _instagramCtrl = TextEditingController();

    _vm.addListener(_onVmChanged);
    if (widget.djId != null) {
      _vm.loadDJ(widget.djId!);
    }
  }

  void _onVmChanged() {
    if (!mounted) return;
    setState(() {});

    // Populate controllers when DJ data arrives for the first time.
    if (_vm.djId != null && _nameCtrl.text.isEmpty && _vm.displayName.isNotEmpty) {
      _nameCtrl.text = _vm.displayName;
      _bioCtrl.text = _vm.bio;
      _nationalityCtrl.text = _vm.nationality;
      _spotifyCtrl.text = _vm.spotifyUrl;
      _soundcloudCtrl.text = _vm.soundcloudUrl;
      _instagramCtrl.text = _vm.instagramUrl;
    }

    if (_vm.isSaved) {
      ToastBanner.show(
        context,
        message: lt('保存成功', 'Saved successfully', '保存しました'),
        type: ToastType.success,
      );
      context.pop();
    }

    if (_vm.errorMessage != null && !_vm.isLoading) {
      ToastBanner.show(
        context,
        message: _vm.errorMessage!,
        type: ToastType.error,
      );
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _nationalityCtrl.dispose();
    _spotifyCtrl.dispose();
    _soundcloudCtrl.dispose();
    _instagramCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final path = await _mediaPicker.pickImage();
    if (path != null) {
      _vm.uploadAvatar(path);
    }
  }

  void _showAddGenreDialog() {
    final controller = TextEditingController();
    final theme = context.raver;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.card,
        title: Text(
          lt('添加流派', 'Add Genre', 'ジャンルを追加'),
          style: TextStyle(color: theme.primaryText),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: lt('例: Techno', 'e.g. Techno', '例: テクノ'),
          ),
          style: TextStyle(color: theme.primaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lt('取消', 'Cancel', 'キャンセル')),
          ),
          TextButton(
            onPressed: () {
              _vm.addGenre(controller.text);
              Navigator.pop(ctx);
            },
            child: Text(lt('确认', 'Confirm', '確認')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final isEdit = widget.djId != null;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: RaverNavigationChrome(
        title: lt('编辑DJ', 'Edit DJ', 'DJ編集'),
        trailing: TextButton(
          onPressed: _vm.isLoading ? null : _vm.save,
          child: _vm.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  lt('保存', 'Save', '保存'),
                  style: RaverTypography.label(
                    size: 15,
                    color: theme.accent,
                    weight: FontWeight.w600,
                  ),
                ),
        ),
      ),
      body: _vm.isLoading && isEdit && _vm.displayName.isEmpty
          ? const Center(child: CircularProgressIndicator.adaptive())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Avatar ----
                  Center(
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: _vm.avatarUrl.isNotEmpty
                          ? Stack(
                              children: [
                                ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: _vm.avatarUrl,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _avatarFallback(theme),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: _editBadge(theme),
                                ),
                              ],
                            )
                          : Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.cardBorder,
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.add_a_photo,
                                  size: 32,
                                  color: theme.secondaryText,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---- Display Name ----
                  _buildLabel(theme, lt('DJ名', 'DJ Name', 'DJ名')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    onChanged: _vm.setDisplayName,
                    decoration: _inputDecoration(
                      theme,
                      hintText:
                          lt('输入DJ名', 'Enter DJ name', 'DJ名を入力'),
                    ),
                    style: RaverTypography.body(
                        size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 20),

                  // ---- Bio ----
                  _buildLabel(theme, lt('简介', 'Bio', '紹介')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bioCtrl,
                    onChanged: _vm.setBio,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      theme,
                      hintText: lt('介绍一下这位DJ', 'Tell us about this DJ',
                          'このDJについて紹介'),
                    ),
                    style: RaverTypography.body(
                        size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 20),

                  // ---- Nationality ----
                  _buildLabel(
                      theme, lt('国籍/地区', 'Nationality', '国籍')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nationalityCtrl,
                    onChanged: _vm.setNationality,
                    decoration: _inputDecoration(
                      theme,
                      hintText: lt('例: 德国', 'e.g. Germany', '例: ドイツ'),
                    ),
                    style: RaverTypography.body(
                        size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 20),

                  // ---- Genre Tags ----
                  _buildLabel(theme, lt('流派', 'Genres', 'ジャンル')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._vm.genres.asMap().entries.map((entry) {
                        return Chip(
                          label: Text(entry.value),
                          onDeleted: () => _vm.removeGenre(entry.key),
                          backgroundColor: theme.accent.withValues(alpha: 0.12),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.accent,
                          ),
                          deleteIconColor: theme.accent,
                          side: BorderSide.none,
                        );
                      }),
                      ActionChip(
                        label: const Icon(Icons.add, size: 18),
                        onPressed: _showAddGenreDialog,
                        backgroundColor: theme.card,
                        side: BorderSide(color: theme.cardBorder),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ---- Social Links ----
                  _buildLabel(theme, 'Spotify URL'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _spotifyCtrl,
                    onChanged: _vm.setSpotifyUrl,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      theme,
                      hintText: 'https://open.spotify.com/artist/...',
                    ),
                    style: RaverTypography.body(
                        size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel(theme, 'SoundCloud URL'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _soundcloudCtrl,
                    onChanged: _vm.setSoundcloudUrl,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      theme,
                      hintText: 'https://soundcloud.com/...',
                    ),
                    style: RaverTypography.body(
                        size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel(theme, 'Instagram URL'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _instagramCtrl,
                    onChanged: _vm.setInstagramUrl,
                    keyboardType: TextInputType.url,
                    decoration: _inputDecoration(
                      theme,
                      hintText: 'https://instagram.com/...',
                    ),
                    style: RaverTypography.body(
                        size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // ---- helpers ----

  Widget _buildLabel(RaverThemeData theme, String text) {
    return Text(
      text,
      style: RaverTypography.label(
        size: 14,
        color: theme.secondaryText,
        weight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _inputDecoration(
    RaverThemeData theme, {
    String? hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.cardBorder),
      ),
    );
  }

  Widget _avatarFallback(RaverThemeData theme) {
    return Container(
      width: 96,
      height: 96,
      color: theme.cardBorder,
      child: Icon(Icons.person, size: 48, color: theme.secondaryText),
    );
  }

  Widget _editBadge(RaverThemeData theme) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.accent,
        shape: BoxShape.circle,
        border: Border.all(color: theme.background, width: 2),
      ),
      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
    );
  }
}
