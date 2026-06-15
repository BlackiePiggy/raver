import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// Widget management screen with available widget list.
class WidgetManageScreen extends StatelessWidget {
  const WidgetManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('桌面小组件', 'Widgets', 'ウィジェット')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _WidgetPreviewCard(
            title: lt('下一场活动', 'Next Event', '次のイベント'),
            description: lt(
              '显示你即将参加的下一场活动信息',
              'Shows your upcoming next event',
              '次に参加予定のイベント情報を表示',
            ),
            icon: Icons.event_outlined,
            theme: theme,
          ),
          const SizedBox(height: 12),
          _WidgetPreviewCard(
            title: lt('签到统计', 'Check-in Stats', 'チェックイン統計'),
            description: lt(
              '显示你的签到总数和连续签到天数',
              'Shows total check-ins and streak',
              'チェックイン合計と連続日数を表示',
            ),
            icon: Icons.check_circle_outline,
            theme: theme,
          ),
          const SizedBox(height: 12),
          _WidgetPreviewCard(
            title: lt('音乐日历', 'Music Calendar', '音楽カレンダー'),
            description: lt(
              '日历视图显示收藏活动的日期',
              'Calendar view of your saved events',
              'お気に入りイベントをカレンダー表示',
            ),
            icon: Icons.calendar_month_outlined,
            theme: theme,
          ),
          const SizedBox(height: 24),
          GlassCard(
            child: Column(
              children: [
                Icon(Icons.info_outline, size: 28, color: theme.secondaryText),
                const SizedBox(height: 8),
                Text(
                  lt(
                    '长按桌面空白处，点击"添加小组件"，搜索 RaveHub 即可添加。',
                    'Long press on your home screen, tap "Add Widget", and search for RaveHub.',
                    'ホーム画面を長押しし、「ウィジェットを追加」をタップして RaveHub を検索してください。',
                  ),
                  style: RaverTypography.body(
                    size: 13,
                    color: theme.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetPreviewCard extends StatelessWidget {
  const _WidgetPreviewCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.theme,
  });

  final String title;
  final String description;
  final IconData icon;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.accent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: RaverTypography.label(
                    size: 15,
                    color: theme.primaryText,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: RaverTypography.caption(color: theme.secondaryText),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
