import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen for configuring which push notification categories are enabled.
///
/// Stores preferences via [SharedPreferences] using keys prefixed with
/// `notif_`.
class NotificationSettingsScreen extends StatefulWidget {
  /// Creates a [NotificationSettingsScreen].
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final Map<String, bool> _prefs = {};
  bool _loaded = false;

  static const _keys = [
    'followed_event_updates',
    'event_starting_soon',
    'new_likes',
    'new_comments',
    'new_followers',
    'followed_dj_updates',
    'followed_label_updates',
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    for (final key in _keys) {
      _prefs[key] = sp.getBool('notif_$key') ?? true;
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _prefs[key] = value);
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('notif_$key', value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: RaverNavigationChrome(
        title: lt('通知设置', 'Notification Settings', '通知設定'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator.adaptive())
          : ListView(
              children: [
                // ---- Event Notifications ----
                _SectionHeader(
                  title: lt('活动通知', 'Event Notifications', 'イベント通知'),
                ),
                _buildSwitch(
                  key: 'followed_event_updates',
                  title: lt(
                    '关注活动更新',
                    'Followed Event Updates',
                    'フォロー中イベント更新',
                  ),
                  theme: theme,
                ),
                _buildSwitch(
                  key: 'event_starting_soon',
                  title: lt(
                    '活动即将开始',
                    'Event Starting Soon',
                    'イベント開始まもなく',
                  ),
                  theme: theme,
                ),

                // ---- Community Notifications ----
                _SectionHeader(
                  title: lt('社区通知', 'Community Notifications', 'コミュニティ通知'),
                ),
                _buildSwitch(
                  key: 'new_likes',
                  title: lt('新赞', 'New Likes', '新しいいいね'),
                  theme: theme,
                ),
                _buildSwitch(
                  key: 'new_comments',
                  title: lt('新评论', 'New Comments', '新しいコメント'),
                  theme: theme,
                ),
                _buildSwitch(
                  key: 'new_followers',
                  title: lt('新关注', 'New Followers', '新しいフォロワー'),
                  theme: theme,
                ),

                // ---- DJ / Labels ----
                _SectionHeader(
                  title: lt('DJ / 厂牌', 'DJ / Labels', 'DJ / レーベル'),
                ),
                _buildSwitch(
                  key: 'followed_dj_updates',
                  title: lt(
                    '关注DJ更新',
                    'Followed DJ Updates',
                    'フォロー中DJ更新',
                  ),
                  theme: theme,
                ),
                _buildSwitch(
                  key: 'followed_label_updates',
                  title: lt(
                    '关注厂牌更新',
                    'Followed Label Updates',
                    'フォロー中レーベル更新',
                  ),
                  theme: theme,
                ),
              ],
            ),
    );
  }

  Widget _buildSwitch({
    required String key,
    required String title,
    required RaverThemeData theme,
  }) {
    return SwitchListTile.adaptive(
      title: Text(
        title,
        style: RaverTypography.body(color: theme.primaryText),
      ),
      value: _prefs[key] ?? true,
      activeColor: theme.accent,
      onChanged: (v) => _toggle(key, v),
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
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: RaverTypography.label(color: theme.secondaryText),
      ),
    );
  }
}
