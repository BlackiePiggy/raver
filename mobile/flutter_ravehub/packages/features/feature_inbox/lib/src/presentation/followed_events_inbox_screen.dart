import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../data/inbox_service_locator.dart';
import 'view_models/inbox_view_model.dart';

/// Inbox screen listing updates from followed events.
///
/// Each row shows: event cover, event name, change type tag, and time.
class FollowedEventsInboxScreen extends StatefulWidget {
  const FollowedEventsInboxScreen({super.key});

  @override
  State<FollowedEventsInboxScreen> createState() =>
      _FollowedEventsInboxScreenState();
}

class _FollowedEventsInboxScreenState extends State<FollowedEventsInboxScreen> {
  late final InboxViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = InboxViewModel(
      repository: InboxServiceLocator.notificationRepository,
    );
    _viewModel.addListener(_rebuild);
    _viewModel.loadFollowedEvents();
    _scrollController.addListener(_onScroll);

    _viewModel.markAsRead(category: 'followed_events', ids: []);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _viewModel.loadMoreFollowedEvents();
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        title: Text(
          lt('关注活动更新', 'Followed Events', 'フォローイベント'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
      ),
      body: LoadPhaseBuilder<List<FollowedEventNotificationItem>>(
        phase: _viewModel.followedEventsPhase,
        onLoading: () => const _FollowedEventsSkeleton(),
        onEmpty: () => EmptyStateView(
          icon: Icons.event_busy,
          title: lt('暂无更新', 'No Updates', '更新はありません'),
          subtitle: lt(
            '您关注的活动暂无变更',
            'Events you follow have no updates yet',
            'フォロー中のイベントの更新はまだありません',
          ),
        ),
        onFailure: (error) => ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.loadFollowedEvents,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
        onSuccess: (_) => RefreshIndicator(
          color: theme.accent,
          onRefresh: _viewModel.refreshFollowedEvents,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _viewModel.followedEvents.length +
                (_viewModel.canLoadMoreFollowedEvents ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= _viewModel.followedEvents.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                );
              }

              final item = _viewModel.followedEvents[index];
              return _FollowedEventTile(
                item: item,
                onTap: () => context.push('/events/${item.eventId}'),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FollowedEventTile extends StatelessWidget {
  const _FollowedEventTile({required this.item, required this.onTap});

  final FollowedEventNotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.cardBorder),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.coverImageUrl.isNotEmpty
                  ? RemoteCoverImage(
                      url: item.coverImageUrl,
                      width: 56,
                      height: 56,
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: theme.cardBorder,
                      child: Icon(
                        Icons.event,
                        color: theme.secondaryText,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.eventName,
                    style: RaverTypography.label(
                      size: 14,
                      color: theme.primaryText,
                      weight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _ChangeTypeTag(changeType: item.changeType),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.summary,
                          style: RaverTypography.caption(
                            color: theme.secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRelativeTime(item.createdAt),
                    style: RaverTypography.caption(
                      color: theme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatRelativeTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return lt('刚刚', 'just now', 'たった今');
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 30) return '${diff.inDays}d';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return iso;
    }
  }
}

class _ChangeTypeTag extends StatelessWidget {
  const _ChangeTypeTag({required this.changeType});

  final String changeType;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final color = _colorForType(changeType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _labelForType(changeType),
        style: RaverTypography.caption(
          color: color,
          weight: FontWeight.w600,
        ),
      ),
    );
  }

  static String _labelForType(String type) => switch (type) {
        'lineup_update' => lt('阵容更新', 'Lineup', 'ラインナップ'),
        'schedule_update' => lt('时间更新', 'Schedule', 'スケジュール'),
        'venue_update' => lt('场地更新', 'Venue', '会場'),
        'cancelled' => lt('已取消', 'Cancelled', 'キャンセル'),
        'new_info' => lt('新消息', 'New Info', '新着情報'),
        _ => type,
      };

  static Color _colorForType(String type) => switch (type) {
        'cancelled' => const Color(0xFFD93636),
        'lineup_update' => const Color(0xFF6B42DB),
        'schedule_update' => const Color(0xFFF88A35),
        'venue_update' => const Color(0xFF4DABF7),
        _ => const Color(0xFF70C754),
      };
}

class _FollowedEventsSkeleton extends StatelessWidget {
  const _FollowedEventsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Row(
          children: const [
            SkeletonBox(width: 56, height: 56, borderRadius: 8),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 160, height: 14),
                  SizedBox(height: 6),
                  SkeletonLine(width: 120, height: 12),
                  SizedBox(height: 4),
                  SkeletonLine(width: 60, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
