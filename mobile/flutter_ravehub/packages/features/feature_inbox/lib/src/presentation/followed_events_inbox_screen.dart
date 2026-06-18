import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../data/inbox_service_locator.dart';
import 'view_models/inbox_view_model.dart';
import 'widgets/followed_update_tile.dart';
import 'widgets/refreshable_empty_state.dart';

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
        onEmpty: () => RefreshableEmptyState(
          onRefresh: _viewModel.refreshFollowedEvents,
          child: EmptyStateView(
            icon: Icons.event_busy,
            title: lt('暂无更新', 'No Updates', '更新はありません'),
            subtitle: lt(
              '您关注的活动暂无变更',
              'Events you follow have no updates yet',
              'フォロー中のイベントの更新はまだありません',
            ),
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
            physics: const AlwaysScrollableScrollPhysics(),
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
              return FollowedUpdateTile(
                entityName: item.eventName,
                updateType: item.type,
                updateTitle: item.newsTitle,
                summary: item.newsSummary,
                occurredAt: item.occurredAt,
                isRead: item.isRead,
                imageUrl: item.newsCoverImageUrl,
                placeholderIcon: Icons.event,
                onTap: () {
                  _viewModel.markFollowedEventRead(item.id);
                  context.push(
                    '/inbox/changes/event/${item.eventId}',
                    extra: {
                      'entityName': item.eventName,
                      'changeType': item.type,
                      'summary': item.newsSummary,
                      'imageUrl': item.newsCoverImageUrl,
                      'updateTitle': item.newsTitle,
                      'targetType': item.type,
                      'targetId': item.newsId,
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
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
