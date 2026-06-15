import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// About screen showing app info, version, and links.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('关于', 'About', 'アプリについて')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // App icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.music_note,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'RaveHub',
                style: RaverTypography.headline(
                  color: theme.primaryText,
                ).copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'v1.0.0 (1)',
                style: RaverTypography.caption(color: theme.secondaryText),
              ),
              const SizedBox(height: 40),
              _AboutLink(
                icon: Icons.description_outlined,
                title: lt('用户协议', 'Terms of Service', '利用規約'),
                theme: theme,
                onTap: () {
                  // TODO: Open URL via url_launcher
                },
              ),
              const SizedBox(height: 8),
              _AboutLink(
                icon: Icons.privacy_tip_outlined,
                title: lt('隐私政策', 'Privacy Policy', 'プライバシーポリシー'),
                theme: theme,
                onTap: () {
                  // TODO: Open URL via url_launcher
                },
              ),
              const SizedBox(height: 8),
              _AboutLink(
                icon: Icons.code_outlined,
                title: lt('开源许可证', 'Open Source Licenses',
                    'オープンソースライセンス'),
                theme: theme,
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'RaveHub',
                    applicationVersion: '1.0.0',
                  );
                },
              ),
              const Spacer(),
              Text(
                'Made with love for ravers',
                style: RaverTypography.caption(color: theme.secondaryText),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutLink extends StatelessWidget {
  const _AboutLink({
    required this.icon,
    required this.title,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String title;
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
      trailing:
          Icon(Icons.open_in_new, color: theme.secondaryText, size: 18),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.cardBorder),
      ),
    );
  }
}
