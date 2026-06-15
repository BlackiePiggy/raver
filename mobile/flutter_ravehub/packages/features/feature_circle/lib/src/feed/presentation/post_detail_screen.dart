import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../view_models/post_detail_view_model.dart';
import '../../_shared/circle_service_locator.dart';

/// Detail view for a single social post with comments.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final PostDetailViewModel _viewModel;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _replyToId;

  @override
  void initState() {
    super.initState();
    _viewModel = PostDetailViewModel(
      postId: widget.postId,
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
      _viewModel.loadMoreComments();
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _commentController.dispose();
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final success = await _viewModel.sendComment(
      text,
      parentId: _replyToId,
    );
    if (success) {
      _commentController.clear();
      _replyToId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          lt('动态详情', 'Post Detail', '投稿詳細'),
          style: RaverTypography.title(size: 17, color: theme.primaryText),
        ),
        elevation: 0,
      ),
      body: LoadPhaseBuilder<Post>(
        phase: _viewModel.phase,
        onLoading: () => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        onFailure: (error) => ErrorStateView(
          title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
          error: error,
          onRetry: _viewModel.load,
          retryLabel: lt('重试', 'Retry', '再試行'),
        ),
        onSuccess: (post) => _buildContent(context, post, theme),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Post post,
    RaverThemeData theme,
  ) {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildPostBody(post, theme)),
              SliverToBoxAdapter(child: _buildActionBar(post, theme)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    lt('评论', 'Comments', 'コメント'),
                    style: RaverTypography.title(
                      size: 16,
                      color: theme.primaryText,
                    ),
                  ),
                ),
              ),
              _buildCommentList(theme),
            ],
          ),
        ),
        _buildCommentInput(theme),
      ],
    );
  }

  Widget _buildPostBody(Post post, RaverThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.cardBorder,
                backgroundImage: post.user.avatarUrl != null
                    ? NetworkImage(post.user.avatarUrl!)
                    : null,
                child: post.user.avatarUrl == null
                    ? Icon(Icons.person, color: theme.secondaryText, size: 22)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.user.displayName,
                      style: RaverTypography.label(
                        size: 15,
                        color: theme.primaryText,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(post.createdAt),
                      style: RaverTypography.caption(
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (post.eventName != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    post.eventName!,
                    style: RaverTypography.caption(
                      size: 11,
                      color: theme.accent,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Content text
          Text(
            post.content,
            style: RaverTypography.body(size: 16, color: theme.primaryText),
          ),

          // Images
          if (post.images != null && post.images!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildImageSection(post.images!, theme),
          ],

          // Videos
          if (post.videos != null && post.videos!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildVideoThumbnail(post.videos!.first, theme),
          ],
        ],
      ),
    );
  }

  Widget _buildImageSection(List<String> images, RaverThemeData theme) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: RemoteCoverImage(
          url: images.first,
          width: double.infinity,
          height: 260,
          fit: BoxFit.cover,
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: RemoteCoverImage(
            url: images[index],
            width: 200,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(String videoUrl, RaverThemeData theme) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Widget _buildActionBar(Post post, RaverThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.cardBorder, width: 0.5),
            bottom: BorderSide(color: theme.cardBorder, width: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionButton(
              icon: (post.isLiked ?? false)
                  ? Icons.favorite
                  : Icons.favorite_border,
              label: '${post.likeCount}',
              color:
                  (post.isLiked ?? false) ? Colors.redAccent : theme.secondaryText,
              onTap: _viewModel.toggleLike,
            ),
            _buildActionButton(
              icon: Icons.chat_bubble_outline,
              label: '${post.commentCount}',
              color: theme.secondaryText,
              onTap: () {},
            ),
            _buildActionButton(
              icon: Icons.share_outlined,
              label: lt('分享', 'Share', 'シェア'),
              color: theme.secondaryText,
              onTap: () {},
            ),
            _buildActionButton(
              icon: (post.isSaved ?? false)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              label: lt('收藏', 'Save', '保存'),
              color: (post.isSaved ?? false) ? theme.accent : theme.secondaryText,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: RaverTypography.caption(
              size: 13,
              color: color,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentList(RaverThemeData theme) {
    if (_viewModel.comments.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              lt('暂无评论', 'No comments yet', 'コメントはまだありません'),
              style: RaverTypography.body(
                size: 14,
                color: theme.secondaryText,
              ),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _viewModel.comments.length) {
            if (_viewModel.canLoadMoreComments) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }
            return const SizedBox.shrink();
          }

          final comment = _viewModel.comments[index];
          return _CommentTile(
            comment: comment,
            theme: theme,
            onReply: () {
              setState(() => _replyToId = comment.id);
            },
          );
        },
        childCount: _viewModel.comments.length +
            (_viewModel.canLoadMoreComments ? 1 : 0),
      ),
    );
  }

  Widget _buildCommentInput(RaverThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(
          top: BorderSide(color: theme.cardBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.cardBorder),
              ),
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: _replyToId != null
                      ? lt('回复评论...', 'Reply...', '返信...')
                      : lt('写评论...', 'Write a comment...', 'コメントを書く...'),
                  hintStyle: RaverTypography.body(
                    size: 14,
                    color: theme.secondaryText,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                style: RaverTypography.body(
                  size: 14,
                  color: theme.primaryText,
                ),
                maxLines: 3,
                minLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _viewModel.isSendingComment ? null : _sendComment,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.accent,
                shape: BoxShape.circle,
              ),
              child: _viewModel.isSendingComment
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.theme,
    required this.onReply,
  });

  final Comment comment;
  final RaverThemeData theme;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.cardBorder,
            backgroundImage: comment.avatarUrl.isNotEmpty
                ? NetworkImage(comment.avatarUrl)
                : null,
            child: comment.avatarUrl.isEmpty
                ? Icon(Icons.person, size: 16, color: theme.secondaryText)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.displayName,
                      style: RaverTypography.label(
                        size: 13,
                        color: theme.primaryText,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatRelative(comment.createdAt),
                      style: RaverTypography.caption(
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: RaverTypography.body(
                    size: 14,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onReply,
                  child: Text(
                    lt('回复', 'Reply', '返信'),
                    style: RaverTypography.caption(
                      size: 12,
                      color: theme.accent,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRelative(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return iso;
    }
  }
}
