import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../data/inbox_service_locator.dart';
import 'view_models/inbox_view_model.dart';

/// Inbox screen listing updates from followed DJs.
class FollowedDjsInboxScreen extends StatefulWidget {
  const FollowedDjsInboxScreen({super.key});

  @override
  State<FollowedDjsInboxScreen> createState() =>
      _FollowedDjsInboxScreenState();
}

class _FollowedDjsInboxScreenState extends State<FollowedDjsInboxScreen> {
  late final InboxViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = InboxViewModel(
      repository: InboxServiceLocator.notificationRepository,
    );
    _viewModel.addListener(_rebuild);
    _viewModel.loadFollowedDJs();
    _scrollController.addListener(_onScroll);

    _viewModel.markAsRead(category: 'followed_djs', ids: []);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _viewModel.loadMoreFollowedDJs();
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
          lt('关注 DJ 更新', 'Followed DJs', 'フォロー DJ'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
      ),
      body: LoadPhaseBuilder<List<FollowedDJNotificationItem>>(
        phase: _viewModel.followedDJsPhase,
        onLoading: () => const _FollowedDJsSkeleton(),
        onEmpty: () => EmptyStateView(
          icon: Icons.headset_off,
          title: lt('暂无更新', 'No Updates', '更新はありません'),
          subtitle: lt(
            '您关注的 DJ 暂无变更',
            'DJs you follow have no updates yet',
            'フォロー中の DJ の更新はまだありません',
          ),
        ),
        onFailure: (error) => ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.loadFollowedDJs,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
        onSuccess: (_) => RefreshIndicator(
          color: theme.accent,
          onRefresh: _viewModel.refreshFollowedDJs,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _viewModel.followedDJs.length +
                (_viewModel.canLoadMoreFollowedDJs ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= _viewModel.followedDJs.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                );
              }

              final item = _viewModel.followedDJs[index];
              return _FollowedDJTile(
                item: item,
                onTap: () => context.push('/djs/${item.djId}'),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FollowedDJTile extends StatelessWidget {
  const _FollowedDJTile({required this.item, required this.onTap});

  final FollowedDJNotificationItem item;
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
            ClipOval(
              child: item.avatarUrl.isNotEmpty
                  ? RemoteCoverImage(
                      url: item.avatarUrl,
                      width: 48,
                      height: 48,
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: theme.cardBorder,
                      child: Icon(
                        Icons.person,
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
                    item.djName,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF70C754).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.changeType,
                          style: RaverTypography.caption(
                            color: const Color(0xFF70C754),
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
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

class _FollowedDJsSkeleton extends StatelessWidget {
  const _FollowedDJsSkeleton();

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
            SkeletonCircle(size: 48),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 140, height: 14),
                  SizedBox(height: 6),
                  SkeletonLine(width: 100, height: 12),
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
