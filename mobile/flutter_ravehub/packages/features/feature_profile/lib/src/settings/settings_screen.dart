import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

import '../_shared/profile_service_locator.dart';

/// Application settings screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _termsUrl = 'https://ravehub.top/legal/terms';
  static const _privacyUrl = 'https://ravehub.top/legal/privacy';
  static const _dataRequestsUrl = 'https://ravehub.top/legal/data-requests';

  Future<void> _openExternalLink(BuildContext context, String url) async {
    try {
      await UrlLauncherService.openExternalUrl(url);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt(
              '无法打开链接，请稍后重试',
              'Unable to open the link. Please try again.',
              'リンクを開けませんでした。もう一度お試しください。',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final refreshToken =
          await ProfileServiceLocator.tokenStore?.readRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await ProfileServiceLocator.profileRepository.logout(
          refreshToken: refreshToken,
        );
      }
      await ProfileServiceLocator.clearAccountSession();
      if (!context.mounted) return;
      context.go('/login');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt(
              '退出登录失败，请稍后重试',
              'Logout failed. Please try again.',
              'ログアウトに失敗しました。もう一度お試しください。',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('设置', 'Settings', '設定')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Section: Account
          _SectionHeader(title: lt('账号', 'Account', 'アカウント')),
          _SettingsItem(
            icon: Icons.security_outlined,
            title: lt('账号安全', 'Account Security', 'アカウントセキュリティ'),
            onTap: () => context.push('/profile/settings/account-security'),
            theme: theme,
          ),
          _SettingsItem(
            icon: Icons.devices_outlined,
            title: lt('设备管理', 'Device Management', 'デバイス管理'),
            onTap: () => context.push('/profile/settings/devices'),
            theme: theme,
          ),
          const SizedBox(height: 16),

          // Section: General
          _SectionHeader(title: lt('通用', 'General', '一般')),
          _SettingsItem(
            icon: Icons.language_outlined,
            title: lt('语言', 'Language', '言語'),
            subtitle: _currentLanguageLabel(),
            onTap: () => context.push('/profile/settings/language'),
            theme: theme,
          ),
          _SettingsItem(
            icon: Icons.palette_outlined,
            title: lt('外观', 'Appearance', '外観'),
            subtitle: lt('跟随系统', 'System', 'システム'),
            onTap: () => context.push('/profile/settings/appearance'),
            theme: theme,
          ),
          _SettingsItem(
            icon: Icons.storage_outlined,
            title: lt('缓存管理', 'Cache Management', 'キャッシュ管理'),
            onTap: () => context.push('/profile/settings/cache'),
            theme: theme,
          ),
          _SettingsItem(
            icon: Icons.app_settings_alt_outlined,
            title: lt('权限引导', 'Permission Guide', '権限ガイド'),
            onTap: () => context.push('/profile/settings/permissions'),
            theme: theme,
          ),
          const SizedBox(height: 16),

          // Section: About
          _SectionHeader(title: lt('其他', 'Other', 'その他')),
          _SettingsItem(
            icon: Icons.description_outlined,
            title: lt('用户协议', 'Terms of Service', '利用規約'),
            onTap: () => _openExternalLink(context, _termsUrl),
            theme: theme,
          ),
          _SettingsItem(
            icon: Icons.privacy_tip_outlined,
            title: lt('隐私政策', 'Privacy Policy', 'プライバシーポリシー'),
            onTap: () => _openExternalLink(context, _privacyUrl),
            theme: theme,
          ),
          _SettingsItem(
            icon: Icons.assignment_outlined,
            title: lt('数据请求', 'Data Requests', 'データリクエスト'),
            onTap: () => _openExternalLink(context, _dataRequestsUrl),
            theme: theme,
          ),
          _SettingsItem(
            icon: Icons.info_outline,
            title: lt('关于', 'About', 'アプリについて'),
            onTap: () => context.push('/profile/settings/about'),
            theme: theme,
          ),
          const SizedBox(height: 32),

          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => _showLogoutConfirmation(context, theme),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    lt('退出登录', 'Log Out', 'ログアウト'),
                    style: RaverTypography.label(
                      size: 16,
                      color: Colors.redAccent,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _currentLanguageLabel() {
    switch (AppLanguagePreference.instance.effectiveLanguage) {
      case AppLanguage.zh:
        return '中文';
      case AppLanguage.en:
        return 'English';
      case AppLanguage.ja:
        return '日本語';
      case AppLanguage.system:
        return lt('跟随系统', 'System', 'システム');
    }
  }

  void _showLogoutConfirmation(BuildContext context, RaverThemeData theme) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.card,
        title: Text(
          lt('确认退出', 'Confirm Logout', 'ログアウトの確認'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
        content: Text(
          lt('确定要退出登录吗？', 'Are you sure you want to log out?',
              'ログアウトしてもよろしいですか？'),
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
              _logout(context);
            },
            child: Text(
              lt('退出', 'Log Out', 'ログアウト'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: RaverTypography.caption(
          color: theme.secondaryText,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.theme,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final RaverThemeData theme;

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
          if (subtitle != null) ...[
            Text(
              subtitle!,
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
