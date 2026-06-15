import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../data/inbox_service_locator.dart';
import 'view_models/inbox_view_model.dart';

/// Inbox screen listing content review status updates.
///
/// Each row shows: entity title, type, and a status label
/// (pending / approved / rejected).
class ContentReviewsInboxScreen extends StatefulWidget {
  const ContentReviewsInboxScreen({super.key});

  @override
  State<ContentReviewsInboxScreen> createState() =>
      _ContentReviewsInboxScreenState();
}

class _ContentReviewsInboxScreenState
    extends State<ContentReviewsInboxScreen> {
  late final InboxViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = InboxViewModel(
      repository: InboxServiceLocator.notificationRepository,
    );
    _viewModel.addListener(_rebuild);
    _viewModel.loadContentReviews();
    _scrollController.addListener(_onScroll);

    _viewModel.markAsRead(category: 'content_reviews', ids: []);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _viewModel.loadMoreContentReviews();
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
          lt('内容审核', 'Content Reviews', 'コンテンツ審査'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
      ),
      body: LoadPhaseBuilder<List<ContentReviewNotificationItem>>(
        phase: _viewModel.contentReviewsPhase,
        onLoading: () => const _ContentReviewsSkeleton(),
        onEmpty: () => EmptyStateView(
          icon: Icons.rate_review_outlined,
          title: lt('暂无审核记录', 'No Reviews', '審査記録はありません'),
          subtitle: lt(
            '您提交的内容审核进度将在这里显示',
            'Review status of your submissions will appear here',
            '投稿内容の審査状況はこちらに表示されます',
          ),
        ),
        onFailure: (error) => ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.loadContentReviews,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
        onSuccess: (_) => RefreshIndicator(
          color: theme.accent,
          onRefresh: _viewModel.refreshContentReviews,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _viewModel.contentReviews.length +
                (_viewModel.canLoadMoreContentReviews ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= _viewModel.contentReviews.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                );
              }

              final item = _viewModel.contentReviews[index];
              return _ContentReviewTile(item: item);
            },
          ),
        ),
      ),
    );
  }
}

class _ContentReviewTile extends StatelessWidget {
  const _ContentReviewTile({required this.item});

  final ContentReviewNotificationItem item;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.entityName,
                  style: RaverTypography.label(
                    size: 15,
                    color: theme.primaryText,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusLabel(status: item.status),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _entityTypeLabel(item.entityType),
                  style: RaverTypography.caption(
                    color: theme.accent,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatRelativeTime(item.createdAt),
                style: RaverTypography.caption(color: theme.secondaryText),
              ),
            ],
          ),
          if (item.reviewNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.reviewNote,
              style: RaverTypography.body(
                size: 13,
                color: theme.secondaryText,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  static String _entityTypeLabel(String type) => switch (type) {
        'event' => lt('活动', 'Event', 'イベント'),
        'dj' => 'DJ',
        'set' => 'Set',
        'news' => lt('资讯', 'News', 'ニュース'),
        'brand' => lt('厂牌', 'Brand', 'ブランド'),
        _ => type,
      };

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

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => (
          lt('已通过', 'Approved', '承認済み'),
          const Color(0xFF1B9E5C),
        ),
      'rejected' => (
          lt('已拒绝', 'Rejected', '却下'),
          const Color(0xFFD93636),
        ),
      'pending' => (
          lt('审核中', 'Pending', '審査中'),
          const Color(0xFFF88A35),
        ),
      _ => (status, const Color(0xFF999999)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: RaverTypography.caption(
          color: color,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ContentReviewsSkeleton extends StatelessWidget {
  const _ContentReviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SkeletonLine(width: 180, height: 16)),
                SizedBox(width: 8),
                SkeletonBox(width: 60, height: 22, borderRadius: 6),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                SkeletonBox(width: 50, height: 18, borderRadius: 4),
                SizedBox(width: 8),
                SkeletonLine(width: 60, height: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
