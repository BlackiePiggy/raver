import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../_shared/profile_service_locator.dart';

/// Account security screen.
class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  bool _isSubmitting = false;

  Future<void> _updateSecurity({
    String? currentPassword,
    String? newPassword,
    String? phone,
    String? email,
  }) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ProfileServiceLocator.profileRepository.updateSecurity(
        currentPassword: currentPassword,
        newPassword: newPassword,
        phone: phone,
        email: email,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt('账号安全已更新', 'Account security updated', 'アカウントセキュリティを更新しました'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt(
              '更新失败，请稍后重试',
              'Update failed. Please try again.',
              '更新に失敗しました。もう一度お試しください。',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ProfileServiceLocator.profileRepository.deleteAccount();
      await ProfileServiceLocator.clearAccountSession();
      if (!mounted) return;
      context.go('/login');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt(
              '删除账号失败，请稍后重试',
              'Account deletion failed. Please try again.',
              'アカウント削除に失敗しました。もう一度お試しください。',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('账号安全', 'Account Security', 'アカウントセキュリティ')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          _SecurityItem(
            icon: Icons.lock_outline,
            title: lt('修改密码', 'Change Password', 'パスワード変更'),
            subtitle: '',
            theme: theme,
            enabled: !_isSubmitting,
            onTap: () => _showChangePasswordDialog(context, theme),
          ),
          _SecurityItem(
            icon: Icons.phone_outlined,
            title: lt('绑定手机号', 'Link Phone', '電話番号のリンク'),
            subtitle: lt('使用当前账号验证', 'Verify current account', '現在のアカウントで確認'),
            theme: theme,
            enabled: !_isSubmitting,
            onTap: () => _showSingleFieldDialog(
              context: context,
              theme: theme,
              title: lt('绑定手机号', 'Link Phone', '電話番号のリンク'),
              hintText: lt('手机号', 'Phone number', '電話番号'),
              keyboardType: TextInputType.phone,
              validator: (value) => value.length >= 6,
              onSubmit: (value) => _updateSecurity(phone: value),
            ),
          ),
          _SecurityItem(
            icon: Icons.email_outlined,
            title: lt('绑定邮箱', 'Link Email', 'メールのリンク'),
            subtitle: lt('使用当前账号验证', 'Verify current account', '現在のアカウントで確認'),
            theme: theme,
            enabled: !_isSubmitting,
            onTap: () => _showSingleFieldDialog(
              context: context,
              theme: theme,
              title: lt('绑定邮箱', 'Link Email', 'メールのリンク'),
              hintText: lt('邮箱', 'Email address', 'メールアドレス'),
              keyboardType: TextInputType.emailAddress,
              validator: _isValidEmail,
              onSubmit: (value) => _updateSecurity(email: value),
            ),
          ),
          const SizedBox(height: 18),
          _SecurityItem(
            icon: Icons.person_remove_outlined,
            title: lt('删除账号', 'Delete Account', 'アカウント削除'),
            subtitle: lt('不可撤销', 'Irreversible', '取り消せません'),
            theme: theme,
            enabled: !_isSubmitting,
            destructive: true,
            onTap: () => _showDeleteAccountConfirmation(context, theme),
          ),
          _SecurityFooter(
            text: lt(
              '删除账号会停用登录凭证、推送设备并清除个人资料。公开内容会按平台审核和法定留存策略处理。',
              'Deleting your account disables login credentials and push devices, then clears your profile. Public content follows platform moderation and legal retention policies.',
              'アカウントを削除するとログイン認証情報とプッシュ端末が無効化され、プロフィールが削除されます。公開コンテンツは審査および法定保存ポリシーに従って処理されます。',
            ),
            theme: theme,
          ),
        ],
      ),
    );
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  void _showChangePasswordDialog(BuildContext context, RaverThemeData theme) {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();
    String? errorText;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.card,
          title: Text(
            lt('修改密码', 'Change Password', 'パスワード変更'),
            style: RaverTypography.title(color: theme.primaryText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPwController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: lt('当前密码', 'Current password', '現在のパスワード'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPwController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: lt('新密码', 'New password', '新しいパスワード'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPwController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: lt('确认新密码', 'Confirm new password', '新しいパスワードを確認'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  errorText!,
                  style: RaverTypography.caption(color: Colors.redAccent),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lt('取消', 'Cancel', 'キャンセル')),
            ),
            TextButton(
              onPressed: () {
                final current = currentPwController.text.trim();
                final next = newPwController.text.trim();
                final confirm = confirmPwController.text.trim();
                if (current.isEmpty || next.length < 8) {
                  setDialogState(() {
                    errorText = lt(
                      '请输入当前密码，新密码至少 8 位',
                      'Enter the current password and use at least 8 characters.',
                      '現在のパスワードを入力し、新しいパスワードは8文字以上にしてください。',
                    );
                  });
                  return;
                }
                if (next != confirm) {
                  setDialogState(() {
                    errorText = lt(
                      '两次输入的新密码不一致',
                      'The new passwords do not match.',
                      '新しいパスワードが一致しません。',
                    );
                  });
                  return;
                }
                Navigator.pop(ctx);
                _updateSecurity(currentPassword: current, newPassword: next);
              },
              child: Text(
                lt('确认', 'Confirm', '確認'),
                style: TextStyle(color: theme.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSingleFieldDialog({
    required BuildContext context,
    required RaverThemeData theme,
    required String title,
    required String hintText,
    required TextInputType keyboardType,
    required bool Function(String value) validator,
    required Future<void> Function(String value) onSubmit,
  }) {
    final controller = TextEditingController();
    String? errorText;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.card,
          title: Text(
            title,
            style: RaverTypography.title(color: theme.primaryText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  errorText!,
                  style: RaverTypography.caption(color: Colors.redAccent),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lt('取消', 'Cancel', 'キャンセル')),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (!validator(value)) {
                  setDialogState(() {
                    errorText = lt(
                      '请输入有效信息',
                      'Enter valid information.',
                      '有効な情報を入力してください。',
                    );
                  });
                  return;
                }
                Navigator.pop(ctx);
                onSubmit(value);
              },
              child: Text(
                lt('确认', 'Confirm', '確認'),
                style: TextStyle(color: theme.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountConfirmation(
    BuildContext context,
    RaverThemeData theme,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.card,
        title: Text(
          lt('删除账号', 'Delete Account', 'アカウント削除'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
        content: Text(
          lt(
            '删除后你将退出登录，账号会被停用并清除个人资料。此操作不可撤销。',
            'After deletion you will be logged out, the account will be disabled, and your profile will be cleared. This cannot be undone.',
            '削除後はログアウトされ、アカウントは無効化され、プロフィールは削除されます。この操作は取り消せません。',
          ),
          style: RaverTypography.body(size: 14, color: theme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lt('取消', 'Cancel', 'キャンセル')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAccount();
            },
            child: Text(
              lt('确认删除账号', 'Confirm Delete Account', 'アカウント削除を確認'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityItem extends StatelessWidget {
  const _SecurityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
    this.enabled = true,
    this.destructive = false,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final RaverThemeData theme;
  final bool enabled;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive ? Colors.redAccent : theme.primaryText;
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: foreground, size: 22),
      title: Text(
        title,
        style: RaverTypography.body(size: 16, color: foreground),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (subtitle.isNotEmpty) ...[
            Text(
              subtitle,
              style: RaverTypography.caption(color: theme.secondaryText),
            ),
            const SizedBox(width: 4),
          ],
          Icon(
            Icons.chevron_right,
            color: destructive ? Colors.redAccent : theme.secondaryText,
            size: 20,
          ),
        ],
      ),
      onTap: enabled ? onTap : null,
    );
  }
}

class _SecurityFooter extends StatelessWidget {
  const _SecurityFooter({
    required this.text,
    required this.theme,
  });

  final String text;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        text,
        style: RaverTypography.caption(color: theme.secondaryText),
      ),
    );
  }
}
