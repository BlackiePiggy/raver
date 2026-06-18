import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

import '../_shared/profile_service_locator.dart';
import 'view_models/edit_profile_view_model.dart';

/// Screen for editing the current user's profile details.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final EditProfileViewModel _viewModel;
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    _viewModel = EditProfileViewModel(
      repository: ProfileServiceLocator.profileRepository,
    );
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _cityController = TextEditingController();
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.load();
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    setState(() {});

    // Sync controllers when profile loads
    if (_viewModel.profile != null && _nameController.text.isEmpty) {
      _nameController.text = _viewModel.displayName;
      _bioController.text = _viewModel.bio;
      _cityController.text = _viewModel.city;
    }

    if (_viewModel.saveSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lt('保存成功', 'Saved successfully', '保存しました')),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('编辑资料', 'Edit Profile', 'プロフィール編集')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _viewModel.canSave ? _viewModel.save : null,
            child: _viewModel.isSaving
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
        ],
      ),
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Background
                  GestureDetector(
                    onTap: _pickBackgroundImage,
                    child: AspectRatio(
                      aspectRatio: 5 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_viewModel.backgroundUrl != null &&
                                _viewModel.backgroundUrl!.isNotEmpty)
                              RemoteCoverImage(
                                url: _viewModel.backgroundUrl!,
                                fit: BoxFit.cover,
                              )
                            else
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      theme.accent.withValues(alpha: 0.42),
                                      Colors.black.withValues(alpha: 0.18),
                                      theme.card,
                                    ],
                                  ),
                                ),
                              ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.18),
                              ),
                            ),
                            Center(
                              child: _viewModel.isUploadingBackground
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.photo_library_outlined,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _viewModel.backgroundUrl == null ||
                                                  _viewModel
                                                      .backgroundUrl!.isEmpty
                                              ? lt('选择背景', 'Select Background',
                                                  '背景を選択')
                                              : lt('更换背景', 'Change Background',
                                                  '背景を変更'),
                                          style: RaverTypography.label(
                                            size: 15,
                                            color: Colors.white,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Avatar
                  Center(
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          ClipOval(
                            child: _viewModel.avatarUrl != null &&
                                    _viewModel.avatarUrl!.isNotEmpty
                                ? RemoteCoverImage(
                                    url: _viewModel.avatarUrl!,
                                    width: 88,
                                    height: 88,
                                  )
                                : Container(
                                    width: 88,
                                    height: 88,
                                    color: theme.cardBorder,
                                    child: Icon(
                                      Icons.person,
                                      size: 44,
                                      color: theme.secondaryText,
                                    ),
                                  ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: theme.accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.background,
                                  width: 2,
                                ),
                              ),
                              child: _viewModel.isUploadingAvatar
                                  ? const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Display name
                  _buildLabel(
                    theme,
                    lt('昵称', 'Display Name', 'ニックネーム'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    onChanged: _viewModel.setDisplayName,
                    onEditingComplete: _viewModel.checkDisplayName,
                    decoration: InputDecoration(
                      hintText: lt('输入昵称', 'Enter display name', 'ニックネームを入力'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.cardBorder),
                      ),
                      errorText: _viewModel.displayNameError,
                      suffixIcon: _viewModel.isCheckingName
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _viewModel.displayNameError != null
                              ? Icon(Icons.error_outline,
                                  color: Colors.redAccent)
                              : null,
                    ),
                    style: RaverTypography.body(
                        size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 20),

                  // Bio
                  _buildLabel(
                    theme,
                    lt('个人简介', 'Bio', '自己紹介'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bioController,
                    onChanged: _viewModel.setBio,
                    maxLines: 4,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText:
                          lt('介绍一下自己', 'Tell us about yourself', '自己紹介を入力'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.cardBorder),
                      ),
                    ),
                    style: RaverTypography.body(
                        size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 20),

                  // Gender
                  _buildLabel(
                    theme,
                    lt('性别', 'Gender', '性別'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue:
                        _viewModel.gender.isEmpty ? null : _viewModel.gender,
                    items: [
                      DropdownMenuItem(
                        value: 'male',
                        child: Text(lt('男', 'Male', '男性')),
                      ),
                      DropdownMenuItem(
                        value: 'female',
                        child: Text(lt('女', 'Female', '女性')),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text(lt('其他', 'Other', 'その他')),
                      ),
                      DropdownMenuItem(
                        value: 'private',
                        child: Text(lt('不公开', 'Private', '非公開')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) _viewModel.setGender(value);
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Birthday
                  _buildLabel(
                    theme,
                    lt('生日', 'Birthday', '誕生日'),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _pickDate(context, theme),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.cardBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _viewModel.birthday.isNotEmpty
                            ? _viewModel.birthday
                            : lt('选择生日', 'Select birthday', '誕生日を選択'),
                        style: RaverTypography.body(
                          size: 16,
                          color: _viewModel.birthday.isNotEmpty
                              ? theme.primaryText
                              : theme.secondaryText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // City
                  _buildLabel(
                    theme,
                    lt('城市', 'City', '都市'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cityController,
                    onChanged: _viewModel.setCity,
                    decoration: InputDecoration(
                      hintText: lt('输入城市', 'Enter city', '都市を入力'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.cardBorder),
                      ),
                    ),
                    style: RaverTypography.body(
                        size: 16, color: theme.primaryText),
                  ),
                  const SizedBox(height: 40),

                  if (_viewModel.error != null) ...[
                    Text(
                      _viewModel.error!,
                      style: RaverTypography.caption(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
    );
  }

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

  Future<void> _pickDate(BuildContext context, RaverThemeData theme) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (picked != null) {
      final formatted =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _viewModel.setBirthday(formatted);
    }
  }

  void _pickAvatar() {
    final theme = context.raver;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  Icon(Icons.photo_library_outlined, color: theme.primaryText),
              title: Text(
                lt('从相册选择', 'Choose from Gallery', 'ギャラリーから選択'),
                style: RaverTypography.body(size: 16, color: theme.primaryText),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatarImage(fromCamera: false);
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.camera_alt_outlined, color: theme.primaryText),
              title: Text(
                lt('拍照', 'Take Photo', '写真を撮る'),
                style: RaverTypography.body(size: 16, color: theme.primaryText),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatarImage(fromCamera: true);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(
                lt('取消', 'Cancel', 'キャンセル'),
                style:
                    RaverTypography.body(size: 16, color: theme.secondaryText),
                textAlign: TextAlign.center,
              ),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatarImage({required bool fromCamera}) async {
    final path = fromCamera
        ? await MediaPickerService.takeSquareImage()
        : await MediaPickerService.pickSquareImageFromGallery();
    if (path == null) return;

    final uploaded = await _viewModel.uploadAvatar(path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          uploaded
              ? lt('头像已上传，保存后生效', 'Avatar uploaded. Save to apply.',
                  'アバターをアップロードしました。保存すると反映されます。')
              : lt('头像上传失败，请稍后重试', 'Avatar upload failed. Please try again.',
                  'アバターのアップロードに失敗しました。もう一度お試しください。'),
        ),
      ),
    );
  }

  Future<void> _pickBackgroundImage() async {
    final path = await MediaPickerService.pickProfileBackgroundImage();
    if (path == null) return;

    final uploaded = await _viewModel.uploadBackground(path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          uploaded
              ? lt('背景已上传，保存后生效', 'Background uploaded. Save to apply.',
                  '背景をアップロードしました。保存すると反映されます。')
              : lt(
                  '背景上传失败，请稍后重试',
                  'Background upload failed. Please try again.',
                  '背景のアップロードに失敗しました。もう一度お試しください。'),
        ),
      ),
    );
  }
}
