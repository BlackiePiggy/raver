import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../data/inbox_service_locator.dart';
import 'view_models/inbox_view_model.dart';
import 'widgets/followed_update_tile.dart';
import 'widgets/refreshable_empty_state.dart';

/// Inbox screen listing updates from followed brands.
class FollowedBrandsInboxScreen extends StatefulWidget {
  const FollowedBrandsInboxScreen({super.key});

  @override
  State<FollowedBrandsInboxScreen> createState() =>
      _FollowedBrandsInboxScreenState();
}

class _FollowedBrandsInboxScreenState extends State<FollowedBrandsInboxScreen> {
  late final InboxViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = InboxViewModel(
      repository: InboxServiceLocator.notificationRepository,
    );
    _viewModel.addListener(_rebuild);
    _viewModel.loadFollowedBrands();
    _scrollController.addListener(_onScroll);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _viewModel.loadMoreFollowedBrands();
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
          lt('关注厂牌更新', 'Followed Brands', 'フォローブランド'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
      ),
      body: LoadPhaseBuilder<List<FollowedBrandNotificationItem>>(
        phase: _viewModel.followedBrandsPhase,
        onLoading: () => const _FollowedBrandsSkeleton(),
        onEmpty: () => RefreshableEmptyState(
          onRefresh: _viewModel.refreshFollowedBrands,
          child: EmptyStateView(
            icon: Icons.storefront_outlined,
            title: lt('暂无更新', 'No Updates', '更新はありません'),
            subtitle: lt(
              '您关注的厂牌暂无变更',
              'Brands you follow have no updates yet',
              'フォロー中のブランドの更新はまだありません',
            ),
          ),
        ),
        onFailure: (error) => ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.loadFollowedBrands,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
        onSuccess: (_) => RefreshIndicator(
          color: theme.accent,
          onRefresh: _viewModel.refreshFollowedBrands,
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _viewModel.followedBrands.length +
                (_viewModel.canLoadMoreFollowedBrands ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= _viewModel.followedBrands.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                );
              }

              final item = _viewModel.followedBrands[index];
              return FollowedUpdateTile(
                entityName: item.brandName,
                updateType: item.type,
                updateTitle: item.newsTitle,
                summary: item.newsSummary,
                occurredAt: item.occurredAt,
                isRead: item.isRead,
                imageUrl: item.imageUrl.isNotEmpty
                    ? item.imageUrl
                    : item.newsCoverImageUrl,
                placeholderIcon: Icons.storefront,
                onTap: () {
                  _viewModel.markFollowedBrandRead(item.id);
                  context.push(
                    '/inbox/changes/brand/${item.brandId}',
                    extra: {
                      'entityName': item.brandName,
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

class _FollowedBrandsSkeleton extends StatelessWidget {
  const _FollowedBrandsSkeleton();

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
            SkeletonBox(width: 48, height: 48, borderRadius: 8),
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
