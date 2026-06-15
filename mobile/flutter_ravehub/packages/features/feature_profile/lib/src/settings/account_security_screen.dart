import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// Account security screen.
class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
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
            onTap: () => _showChangePasswordDialog(context, theme),
          ),
          _SecurityItem(
            icon: Icons.phone_outlined,
            title: lt('绑定手机号', 'Link Phone', '電話番号のリンク'),
            subtitle: lt('未绑定', 'Not linked', '未リンク'),
            theme: theme,
            onTap: () {
              // TODO: Implement phone binding
            },
          ),
          _SecurityItem(
            icon: Icons.email_outlined,
            title: lt('绑定邮箱', 'Link Email', 'メールのリンク'),
            subtitle: lt('未绑定', 'Not linked', '未リンク'),
            theme: theme,
            onTap: () {
              // TODO: Implement email binding
            },
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(
      BuildContext context, RaverThemeData theme) {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lt('取消', 'Cancel', 'キャンセル')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Call API
            },
            child: Text(
              lt('确认', 'Confirm', '確認'),
              style: TextStyle(color: theme.accent),
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
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final RaverThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: theme.primaryText, size: 22),
      title: Text(
        title,
        style: RaverTypography.body(size: 16, color: theme.primaryText),
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
          Icon(Icons.chevron_right, color: theme.secondaryText, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}
