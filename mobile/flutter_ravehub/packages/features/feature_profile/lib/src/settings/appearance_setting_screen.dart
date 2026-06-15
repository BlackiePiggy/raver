import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// Appearance / theme setting screen.
class AppearanceSettingScreen extends StatefulWidget {
  const AppearanceSettingScreen({super.key});

  @override
  State<AppearanceSettingScreen> createState() =>
      _AppearanceSettingScreenState();
}

class _AppearanceSettingScreenState extends State<AppearanceSettingScreen> {
  int _selected = 0; // 0: system, 1: light, 2: dark

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('外观', 'Appearance', '外観')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          _AppearanceOption(
            icon: Icons.settings_brightness,
            title: lt('跟随系统', 'Follow System', 'システムに従う'),
            isSelected: _selected == 0,
            theme: theme,
            onTap: () => setState(() => _selected = 0),
          ),
          _AppearanceOption(
            icon: Icons.light_mode_outlined,
            title: lt('浅色', 'Light', 'ライト'),
            isSelected: _selected == 1,
            theme: theme,
            onTap: () => setState(() => _selected = 1),
          ),
          _AppearanceOption(
            icon: Icons.dark_mode_outlined,
            title: lt('深色', 'Dark', 'ダーク'),
            isSelected: _selected == 2,
            theme: theme,
            onTap: () => setState(() => _selected = 2),
          ),
        ],
      ),
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool isSelected;
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
      trailing: isSelected
          ? Icon(Icons.check, color: theme.accent, size: 22)
          : null,
      onTap: onTap,
    );
  }
}
