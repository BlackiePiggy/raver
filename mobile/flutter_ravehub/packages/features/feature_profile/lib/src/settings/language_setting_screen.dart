import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// Language setting screen with 4 options.
class LanguageSettingScreen extends StatefulWidget {
  const LanguageSettingScreen({super.key});

  @override
  State<LanguageSettingScreen> createState() => _LanguageSettingScreenState();
}

class _LanguageSettingScreenState extends State<LanguageSettingScreen> {
  late AppLanguage _selected;

  @override
  void initState() {
    super.initState();
    _selected = AppLanguagePreference.instance.language;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('语言', 'Language', '言語')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          _LanguageOption(
            title: lt('跟随系统', 'Follow System', 'システムに従う'),
            isSelected: _selected == AppLanguage.system,
            theme: theme,
            onTap: () => _select(AppLanguage.system),
          ),
          _LanguageOption(
            title: '中文',
            isSelected: _selected == AppLanguage.zh,
            theme: theme,
            onTap: () => _select(AppLanguage.zh),
          ),
          _LanguageOption(
            title: 'English',
            isSelected: _selected == AppLanguage.en,
            theme: theme,
            onTap: () => _select(AppLanguage.en),
          ),
          _LanguageOption(
            title: '日本語',
            isSelected: _selected == AppLanguage.ja,
            theme: theme,
            onTap: () => _select(AppLanguage.ja),
          ),
        ],
      ),
    );
  }

  void _select(AppLanguage language) {
    setState(() => _selected = language);
    AppLanguagePreference.instance.language = language;
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.title,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final RaverThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
