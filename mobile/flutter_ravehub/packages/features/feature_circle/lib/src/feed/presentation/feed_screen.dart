import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../view_models/feed_view_model.dart';
import '../../_shared/circle_service_locator.dart';

/// Social feed showing posts from followed users and recommendations.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final FeedViewModel _viewModel;
  final ScrollController _scrollController = ScrollController();
  int _segmentIndex = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = FeedViewModel(
      repository: CircleServiceLocator.feedRepository,
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: RaverSegmentedControl(
                  segments: [
                    lt('关注', 'Following', 'フォロー中'),
                    lt('推荐', 'Recommended', 'おすすめ'),
                  ],
                  selectedIndex: _segmentIndex,
                  onChanged: (index) {
                    setState(() => _segmentIndex = index);
                    _viewModel.setFeedType(
                      index == 0 ? FeedType.following : FeedType.recommended,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => context.push('/circle/compose'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LoadPhaseBuilder<List<Post>>(
            phase: _viewModel.phase,
            onLoading: () => const FeedSkeleton(),
            onEmpty: () => EmptyStateView(
              icon: Icons.dynamic_feed_outlined,
              title: lt('暂无动态', 'No Posts Yet', 'まだ投稿がありません'),
              subtitle: lt(
                '关注更多好友来看他们的动态',
                'Follow more friends to see their posts',
                'フォローして投稿を見ましょう',
              ),
            ),
            onFailure: (error) => ErrorStateView(
              title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
              error: error,
              onRetry: _viewModel.load,
              retryLabel: lt('重试', 'Retry', '再試行'),
            ),
            onSuccess: (_) => _buildFeedList(theme),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedList(RaverThemeData theme) {
    return RefreshIndicator(
      color: theme.accent,
      onRefresh: _viewModel.refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount:
            _viewModel.posts.length + (_viewModel.canLoadMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index >= _viewModel.posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }

          final post = _viewModel.posts[index];
          return PostCardView(
            post: PostCardData(
              id: post.id,
              authorName: post.user.displayName,
              authorAvatarUrl: post.user.avatarUrl,
              content: post.content,
              createdAt: _formatRelativeTime(post.createdAt),
              images: post.images ?? [],
              likeCount: post.likeCount,
              commentCount: post.commentCount,
              shareCount: post.shareCount,
              isLiked: post.isLiked ?? false,
              squadName: post.squad?.name,
              eventName: post.eventName,
            ),
            onTap: () => context.push('/circle/post/${post.id}'),
            onLike: () => _viewModel.toggleLike(index),
            onComment: () => context.push('/circle/post/${post.id}'),
            onShare: () {
              // TODO: Implement share
            },
          );
        },
      ),
    );
  }

  static String _formatRelativeTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return lt('刚刚', 'Just now', 'たった今');
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return iso;
    }
  }
}
