import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../_shared/profile_service_locator.dart';
import 'view_models/saves_view_model.dart';

/// Screen listing saved content by type.
class SavesScreen extends StatefulWidget {
  const SavesScreen({super.key});

  @override
  State<SavesScreen> createState() => _SavesScreenState();
}

class _SavesScreenState extends State<SavesScreen> {
  late final SavesViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = SavesViewModel(
      repository: ProfileServiceLocator.profileRepository,
    );
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
        title: Text(lt('我的收藏', 'My Saves', 'マイお気に入り')),
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
                lt('活动', 'Events', 'イベント'),
                'DJ',
                'Set',
                lt('动态', 'Posts', '投稿'),
              ],
              selectedIndex: _viewModel.selectedTab,
              onChanged: _viewModel.setSelectedTab,
            ),
          ),
          Expanded(
            child: LoadPhaseBuilder<List<Post>>(
              phase: _viewModel.phase,
              onLoading: () => const Center(
                child: CircularProgressIndicator.adaptive(),
              ),
              onEmpty: () => EmptyStateView(
                icon: Icons.bookmark_outline,
                title: lt('暂无收藏', 'No Saves', 'お気に入りなし'),
                subtitle: lt('收藏的内容将显示在这里',
                    'Saved content will appear here',
                    '保存したコンテンツがここに表示されます'),
              ),
              onFailure: (error) => ErrorStateView(
                title:
                    lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
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
            _viewModel.saves.length + (_viewModel.canLoadMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= _viewModel.saves.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }

          final post = _viewModel.saves[index];
          return PostCardView(
            post: PostCardData(
              id: post.id,
              authorName: post.user.displayName,
              authorAvatarUrl: post.user.avatarUrl,
              content: post.content,
              createdAt: post.createdAt,
              images: post.images ?? [],
              likeCount: post.likeCount,
              commentCount: post.commentCount,
              shareCount: post.shareCount,
              isLiked: post.isLiked ?? false,
              eventName: post.eventName,
            ),
          );
        },
      ),
    );
  }
}
