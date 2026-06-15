import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../_shared/profile_service_locator.dart';
import 'view_models/publishes_view_model.dart';

/// Screen listing content published by the current user.
class MyPublishesScreen extends StatefulWidget {
  const MyPublishesScreen({super.key});

  @override
  State<MyPublishesScreen> createState() => _MyPublishesScreenState();
}

class _MyPublishesScreenState extends State<MyPublishesScreen> {
  late final PublishesViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = PublishesViewModel(api: ProfileServiceLocator.publishesApi);
    _viewModel.addListener(_rebuild);
    _viewModel.load();
    _scrollController.addListener(_onScroll);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _viewModel.loadMore();
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
      appBar: AppBar(
        title: Text(lt('我的发布', 'My Publishes', 'マイ投稿管理')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: RaverSegmentedControl(
              segments: [
                lt('活动', 'Event', 'イベント'),
                'DJ',
                'Set',
                lt('新闻', 'News', 'ニュース'),
              ],
              selectedIndex: _viewModel.selectedTab,
              onChanged: _viewModel.setSelectedTab,
            ),
          ),
          Expanded(
            child: LoadPhaseBuilder<List<ContentSubmissionSummary>>(
              phase: _viewModel.phase,
              onLoading: () => const Center(
                child: CircularProgressIndicator.adaptive(),
              ),
              onEmpty: () => EmptyStateView(
                icon: Icons.article_outlined,
                title: lt('暂无发布', 'No Submissions', '投稿なし'),
                subtitle: lt('你还没有提交过内容',
                    'You haven\'t submitted any content yet',
                    'まだコンテンツを投稿していません'),
              ),
              onFailure: (error) => ErrorStateView(
                title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
                error: error,
                onRetry: _viewModel.load,
                retryLabel: lt('重试', 'Retry', '再試行'),
              ),
              onSuccess: (_) => _buildList(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(RaverThemeData theme) {
    return RefreshIndicator(
      color: theme.accent,
      onRefresh: _viewModel.refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount:
            _viewModel.submissions.length + (_viewModel.canLoadMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= _viewModel.submissions.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }

          final item = _viewModel.submissions[index];
          return _SubmissionCard(
            item: item,
            theme: theme,
            onTap: () => context.push('/profile/publishes/${item.id}'),
          );
        },
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.item,
    required this.theme,
    required this.onTap,
  });

  final ContentSubmissionSummary item;
  final RaverThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.entityName,
                    style: RaverTypography.label(
                      size: 15,
                      color: theme.primaryText,
                      weight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        item.entityType.toUpperCase(),
                        style: RaverTypography.caption(
                          color: theme.secondaryText,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.createdAt,
                        style: RaverTypography.caption(
                            color: theme.secondaryText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _StatusBadge(status: item.status, theme: theme),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                color: theme.secondaryText, size: 20),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.theme});

  final String status;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        label = lt('待审核', 'Pending', '審査中');
        break;
      case 'approved':
        color = Colors.green;
        label = lt('已通过', 'Approved', '承認済み');
        break;
      case 'rejected':
        color = Colors.redAccent;
        label = lt('已拒绝', 'Rejected', '却下');
        break;
      default:
        color = theme.secondaryText;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
