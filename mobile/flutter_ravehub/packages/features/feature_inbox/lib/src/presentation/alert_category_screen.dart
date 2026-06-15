import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../data/inbox_service_locator.dart';
import 'view_models/inbox_view_model.dart';

/// Screen showing community alert notifications for a specific category.
///
/// Lists notifications with trigger user avatar, description text, relative
/// time, and tap-to-navigate.
class AlertCategoryScreen extends StatefulWidget {
  const AlertCategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  State<AlertCategoryScreen> createState() => _AlertCategoryScreenState();
}

class _AlertCategoryScreenState extends State<AlertCategoryScreen> {
  late final InboxViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = InboxViewModel(
      repository: InboxServiceLocator.notificationRepository,
    );
    _viewModel.addListener(_rebuild);
    _viewModel.loadAlerts();
    _scrollController.addListener(_onScroll);

    // Mark all community alerts as read on enter.
    _viewModel.markAsRead(category: 'community', ids: []);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _viewModel.loadMoreAlerts();
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
          lt('社区互动', 'Community', 'コミュニティ'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
      ),
      body: LoadPhaseBuilder<List<AppNotification>>(
        phase: _viewModel.alertsPhase,
        onLoading: () => const _AlertsSkeleton(),
        onEmpty: () => EmptyStateView(
          icon: Icons.notifications_none,
          title: lt('暂无通知', 'No Notifications', '通知はありません'),
        ),
        onFailure: (error) => ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.loadAlerts,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
        onSuccess: (_) => RefreshIndicator(
          color: theme.accent,
          onRefresh: _viewModel.refreshAlerts,
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _viewModel.alerts.length +
                (_viewModel.canLoadMoreAlerts ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index >= _viewModel.alerts.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                );
              }

              final notification = _viewModel.alerts[index];
              return _AlertTile(notification: notification);
            },
          ),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: notification.isRead
            ? theme.card
            : theme.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: notification.imageUrl.isNotEmpty
                ? RemoteCoverImage(
                    url: notification.imageUrl,
                    width: 40,
                    height: 40,
                  )
                : Container(
                    width: 40,
                    height: 40,
                    color: theme.cardBorder,
                    child: Icon(
                      Icons.person,
                      color: theme.secondaryText,
                      size: 22,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: RaverTypography.label(
                    size: 14,
                    color: theme.primaryText,
                    weight: notification.isRead
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  notification.body,
                  style: RaverTypography.body(
                    size: 13,
                    color: theme.secondaryText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatRelativeTime(notification.createdAt),
                  style: RaverTypography.caption(
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          if (!notification.isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, left: 6),
              decoration: BoxDecoration(
                color: theme.accent,
                shape: BoxShape.circle,
              ),
            ),
        ],
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

class _AlertsSkeleton extends StatelessWidget {
  const _AlertsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Row(
          children: const [
            SkeletonCircle(size: 40),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 160, height: 14),
                  SizedBox(height: 6),
                  SkeletonLine(width: 220, height: 12),
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
