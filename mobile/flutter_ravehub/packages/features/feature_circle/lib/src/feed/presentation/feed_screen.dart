import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

import 'view_models/feed_view_model.dart';
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
    _viewModel = FeedViewModel(repository: CircleServiceLocator.feedRepository);
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

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: RaverMotion.normal,
      curve: RaverMotion.curve,
    );
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

    return RaverTabReselectionListener(
      tabIndex: 1,
      onReselected: _scrollToTop,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: RaverSegmentedControl(
                  segments: [
                    lt('推荐', 'Recommended', 'おすすめ'),
                    lt('关注', 'Following', 'フォロー中'),
                    lt('最新', 'Latest', '最新'),
                  ],
                  selectedIndex: _segmentIndex,
                  onChanged: (index) {
                    setState(() => _segmentIndex = index);
                    _viewModel.setFeedType(FeedType.values[index]);
                  },
                ),
              ),
              Expanded(
                child: LoadPhaseBuilder<List<Post>>(
                  phase: _viewModel.phase,
                  onLoading: () => const FeedSkeleton(),
                  onEmpty: () => EmptyStateView(
                    icon: Icons.edit_square,
                    title: lt('还没有动态', 'No Posts Yet', '投稿はまだありません'),
                    subtitle: lt(
                      '成为第一个发帖的人，开始你的社群互动。',
                      'Be the first to post and start your community interaction.',
                      '最初の投稿者になって、コミュニティで交流を始めましょう。',
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
          ),
          Positioned(
            right: 24,
            bottom: 112,
            child: GestureDetector(
              onTap: () => context.push('/circle/compose'),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedList(RaverThemeData theme) {
    return RefreshIndicator(
      color: theme.accent,
      onRefresh: _viewModel.refresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 160),
        itemCount: _viewModel.posts.length + (_viewModel.canLoadMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index >= _viewModel.posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }

          final post = _viewModel.posts[index];
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _viewModel.trackImpressionIfNeeded(index);
          });
          return PostCardView(
            post: PostCardData(
              id: post.id,
              authorName: post.user.displayName,
              authorAvatarUrl: post.user.avatarUrl,
              content: post.content,
              createdAt: _formatRelativeTime(post.createdAt),
              images: post.images ?? [],
              videos: post.videos ?? [],
              likeCount: post.likeCount,
              commentCount: post.commentCount,
              shareCount: post.shareCount,
              saveCount: post.saveCount,
              isLiked: post.isLiked ?? false,
              isSaved: post.isSaved ?? false,
              squadName: post.squad?.name,
              eventName: post.eventName,
            ),
            onTap: () {
              _viewModel.trackOpenPost(index);
              context.push('/circle/post/${post.id}');
            },
            onLike: () => _viewModel.toggleLike(index),
            onComment: () {
              _viewModel.trackOpenPost(index);
              context.push('/circle/post/${post.id}');
            },
            onShare: () => _sharePost(index),
            onSave: () => _viewModel.toggleSave(index),
            onMoreTap: () => _showPostActions(index),
          );
        },
      ),
    );
  }

  Future<void> _showPostActions(int index) async {
    if (index < 0 || index >= _viewModel.posts.length) return;
    final theme = context.raver;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.card,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: Text(lt('不感兴趣', 'Not Interested', '興味なし')),
                  subtitle: Text(
                    lt(
                      '减少此类动态推荐',
                      'See fewer posts like this',
                      'このような投稿を減らします',
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _hidePost(index);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(lt('举报', 'Report', '通報')),
                  subtitle: Text(
                    lt(
                      '提交给审核团队处理',
                      'Send this to the moderation team',
                      '審査チームに送信します',
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showReportSheet(index);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReportSheet(int index) async {
    if (index < 0 || index >= _viewModel.posts.length) return;
    await ReportSheet.show(
      context,
      contentType: lt('动态', 'Post', '投稿'),
      onSubmit: (reason, details) async {
        final success = await _viewModel.reportPost(
          index,
          reason: reason.value,
          detail: details,
        );
        if (!success) throw StateError('report failed');
        if (!mounted) return;
        ToastBanner.show(
          context,
          message: lt('举报已提交', 'Report submitted', '報告を送信しました'),
          type: ToastType.success,
        );
      },
    );
  }

  Future<void> _hidePost(int index) async {
    final success = await _viewModel.hidePost(index);
    if (!mounted) return;
    ToastBanner.show(
      context,
      message: success
          ? lt('已减少此类动态', 'Post hidden', '投稿を非表示にしました')
          : lt('操作失败，请稍后再试', 'Action failed. Try again later.', '操作に失敗しました'),
      type: success ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _sharePost(int index) async {
    if (index < 0 || index >= _viewModel.posts.length) return;
    final post = _viewModel.posts[index];
    final fallbackUrl = 'https://ravehub.top/circle/post/${post.id}';

    try {
      final url = await _viewModel.resolveShareUrl(index);
      await ShareService.shareUrl(url, subject: post.user.displayName);
      await _viewModel.reportShare(index);
    } catch (e) {
      await ShareService.shareUrl(fallbackUrl, subject: post.user.displayName);
      if (!mounted) return;
      ToastBanner.show(
        context,
        message: lt('已使用备用链接分享', 'Shared fallback link', '予備リンクを共有しました'),
        type: ToastType.info,
      );
    }
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
