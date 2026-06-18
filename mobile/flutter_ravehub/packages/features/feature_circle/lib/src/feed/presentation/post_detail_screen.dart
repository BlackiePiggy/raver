import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

import 'view_models/post_detail_view_model.dart';
import '../../_shared/circle_service_locator.dart';

/// Detail view for a single social post with comments.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  static const int _replyPreviewCount = 3;
  static const int _replyPageSize = 6;

  late final PostDetailViewModel _viewModel;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _expandedRootCommentIds = {};
  final Map<String, int> _visibleReplyCountByRoot = {};
  Comment? _replyToComment;

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
      parentId: _replyToComment?.id,
    );
    if (success) {
      final replyTarget = _replyToComment;
      _commentController.clear();
      _replyToComment = null;
      if (replyTarget != null) {
        _expandThreadAfterReply(replyTarget);
      }
    }
  }

  Future<void> _sharePost(Post post) async {
    final fallbackUrl = 'https://ravehub.top/circle/post/${post.id}';
    try {
      final url = await _viewModel.resolveShareUrl();
      await ShareService.shareUrl(url, subject: post.user.displayName);
      await _viewModel.reportShare();
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

  Future<void> _showPostActions() async {
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
                    _hidePost();
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
                    _showReportSheet();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReportSheet() async {
    await ReportSheet.show(
      context,
      contentType: lt('动态', 'Post', '投稿'),
      onSubmit: (reason, details) async {
        final success = await _viewModel.reportPost(
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

  Future<void> _hidePost() async {
    final success = await _viewModel.hidePost();
    if (!mounted) return;
    if (success) {
      ToastBanner.show(
        context,
        message: lt('已减少此类动态', 'Post hidden', '投稿を非表示にしました'),
        type: ToastType.success,
      );
      if (context.canPop()) context.pop();
      return;
    }
    ToastBanner.show(
      context,
      message: lt(
        '操作失败，请稍后再试',
        'Action failed. Try again later.',
        '操作に失敗しました',
      ),
      type: ToastType.error,
    );
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
        actions: [
          if (_viewModel.post != null)
            IconButton(
              tooltip: lt('更多', 'More', 'その他'),
              icon: Icon(Icons.more_horiz, color: theme.primaryText),
              onPressed: _showPostActions,
            ),
        ],
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
    return GestureDetector(
      onTap: () => UrlLauncherService.openExternalUrl(videoUrl),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryText.withValues(alpha: 0.12),
                    theme.accent.withValues(alpha: 0.18),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Text(
                _videoFileName(videoUrl),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RaverTypography.caption(
                  color: theme.primaryText,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _videoFileName(String value) {
    final uri = Uri.tryParse(value);
    final path = uri?.path.isNotEmpty == true ? uri!.path : value;
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index >= 0 ? normalized.substring(index + 1) : normalized;
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
              color: (post.isLiked ?? false)
                  ? Colors.redAccent
                  : theme.secondaryText,
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
              label: post.shareCount > 0
                  ? '${post.shareCount}'
                  : lt('分享', 'Share', 'シェア'),
              color: theme.secondaryText,
              onTap: () => _sharePost(post),
            ),
            _buildActionButton(
              icon: (post.isSaved ?? false)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              label: post.saveCount > 0
                  ? '${post.saveCount}'
                  : lt('收藏', 'Save', '保存'),
              color:
                  (post.isSaved ?? false) ? theme.accent : theme.secondaryText,
              onTap: _viewModel.toggleSave,
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
    final threads = _buildCommentThreads(_viewModel.comments);
    if (threads.isEmpty) {
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
          if (index >= threads.length) {
            if (_viewModel.canLoadMoreComments) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator.adaptive()),
              );
            }
            return const SizedBox.shrink();
          }

          final thread = threads[index];
          return _CommentThreadTile(
            thread: thread,
            replyPreviewCount: _replyPreviewCount,
            visibleReplyCount: _visibleReplyCountFor(thread),
            isExpanded: _expandedRootCommentIds.contains(thread.id),
            theme: theme,
            onReply: (comment) => setState(() => _replyToComment = comment),
            onExpand: () => _expandReplies(thread),
            onCollapse: () => _collapseReplies(thread),
            onLoadMoreReplies: () => _loadMoreReplies(thread),
          );
        },
        childCount: threads.length + (_viewModel.canLoadMoreComments ? 1 : 0),
      ),
    );
  }

  List<_CommentThread> _buildCommentThreads(List<Comment> comments) {
    final ordered = comments.toList()
      ..sort((a, b) => _commentDate(a).compareTo(_commentDate(b)));
    final commentById = {for (final comment in ordered) comment.id: comment};
    final rootCache = <String, String>{};

    String? resolveRootId(String commentId) {
      final cached = rootCache[commentId];
      if (cached != null) return cached;
      final comment = commentById[commentId];
      if (comment == null) return null;
      if (_normalizedId(comment.parentCommentId) == null) {
        rootCache[commentId] = commentId;
        return commentId;
      }
      final explicitRoot = _normalizedId(comment.rootCommentId);
      if (explicitRoot != null) {
        rootCache[commentId] = explicitRoot;
        return explicitRoot;
      }

      final visited = <String>{commentId};
      var currentParentId = _normalizedId(comment.parentCommentId);
      while (currentParentId != null &&
          !visited.contains(currentParentId) &&
          commentById[currentParentId] != null) {
        final parent = commentById[currentParentId]!;
        if (_normalizedId(parent.parentCommentId) == null) {
          rootCache[commentId] = currentParentId;
          return currentParentId;
        }
        final parentExplicitRoot = _normalizedId(parent.rootCommentId);
        if (parentExplicitRoot != null) {
          rootCache[commentId] = parentExplicitRoot;
          return parentExplicitRoot;
        }
        visited.add(currentParentId);
        currentParentId = _normalizedId(parent.parentCommentId);
      }
      return null;
    }

    final roots = <Comment>[];
    final repliesByRoot = <String, List<Comment>>{};
    for (final comment in ordered) {
      final rootId = resolveRootId(comment.id);
      if (rootId == null) continue;
      if (_normalizedId(comment.parentCommentId) == null ||
          rootId == comment.id) {
        roots.add(comment);
      } else {
        repliesByRoot.putIfAbsent(rootId, () => []).add(comment);
      }
    }

    final now = DateTime.now();
    final threads = roots.map((root) {
      final replies = repliesByRoot[root.id] ?? const <Comment>[];
      final lastActivityAt =
          replies.isNotEmpty ? _commentDate(replies.last) : _commentDate(root);
      final ageHours = now.difference(lastActivityAt).inMinutes / 60;
      final recencyBonus = 24 / (ageHours.clamp(0, 1000000) + 2);
      final hotScore = replies.length * 3 + recencyBonus;
      return _CommentThread(
        parent: root,
        replies: replies,
        lastActivityAt: lastActivityAt,
        hotScore: hotScore.toDouble(),
      );
    }).toList();

    threads.sort((a, b) {
      final hotCompare = b.hotScore.compareTo(a.hotScore);
      if (hotCompare != 0) return hotCompare;
      return b.lastActivityAt.compareTo(a.lastActivityAt);
    });
    return threads;
  }

  String? _normalizedId(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  DateTime _commentDate(Comment comment) {
    return DateTime.tryParse(comment.createdAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _visibleReplyCountFor(_CommentThread thread) {
    if (thread.replies.isEmpty) return 0;
    if (!_expandedRootCommentIds.contains(thread.id)) {
      return thread.replies.length < _replyPreviewCount
          ? thread.replies.length
          : _replyPreviewCount;
    }
    final defaultCount = thread.replies.length < _replyPageSize
        ? thread.replies.length
        : _replyPageSize;
    return (_visibleReplyCountByRoot[thread.id] ?? defaultCount)
        .clamp(_replyPreviewCount, thread.replies.length)
        .toInt();
  }

  void _expandReplies(_CommentThread thread) {
    setState(() {
      _expandedRootCommentIds.add(thread.id);
      _visibleReplyCountByRoot[thread.id] = _visibleReplyCountFor(thread);
    });
  }

  void _collapseReplies(_CommentThread thread) {
    setState(() => _expandedRootCommentIds.remove(thread.id));
  }

  void _loadMoreReplies(_CommentThread thread) {
    setState(() {
      final current = _visibleReplyCountFor(thread);
      _expandedRootCommentIds.add(thread.id);
      _visibleReplyCountByRoot[thread.id] =
          (current + _replyPageSize).clamp(0, thread.replies.length).toInt();
    });
  }

  void _expandThreadAfterReply(Comment replyTarget) {
    final rootId = _normalizedId(replyTarget.rootCommentId) ??
        (_normalizedId(replyTarget.parentCommentId) == null
            ? replyTarget.id
            : replyTarget.parentCommentId);
    setState(() {
      _expandedRootCommentIds.add(rootId);
      _visibleReplyCountByRoot[rootId] =
          (_visibleReplyCountByRoot[rootId] ?? _replyPreviewCount) + 1;
    });
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyToComment != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            lt(
                              '正在回复 ${_replyToComment!.displayName}',
                              'Replying to ${_replyToComment!.displayName}',
                              '${_replyToComment!.displayName} に返信中',
                            ),
                            style: RaverTypography.caption(
                              color: theme.secondaryText,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _replyToComment = null),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.cardBorder),
                  ),
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: _replyToComment != null
                          ? lt(
                              '回复 ${_replyToComment!.displayName}...',
                              'Reply to ${_replyToComment!.displayName}...',
                              '${_replyToComment!.displayName} に返信...',
                            )
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
              ],
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

class _CommentThread {
  const _CommentThread({
    required this.parent,
    required this.replies,
    required this.lastActivityAt,
    required this.hotScore,
  });

  final Comment parent;
  final List<Comment> replies;
  final DateTime lastActivityAt;
  final double hotScore;

  String get id => parent.id;
}

class _CommentThreadTile extends StatelessWidget {
  const _CommentThreadTile({
    required this.thread,
    required this.replyPreviewCount,
    required this.visibleReplyCount,
    required this.isExpanded,
    required this.theme,
    required this.onReply,
    required this.onExpand,
    required this.onCollapse,
    required this.onLoadMoreReplies,
  });

  final _CommentThread thread;
  final int replyPreviewCount;
  final int visibleReplyCount;
  final bool isExpanded;
  final RaverThemeData theme;
  final ValueChanged<Comment> onReply;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final VoidCallback onLoadMoreReplies;

  @override
  Widget build(BuildContext context) {
    final replies = thread.replies.take(visibleReplyCount).toList();
    final remaining = thread.replies.length - visibleReplyCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentTile(
            comment: thread.parent,
            theme: theme,
            onReply: () => onReply(thread.parent),
          ),
          if (replies.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...replies.map(
              (reply) => _CommentTile(
                comment: reply,
                theme: theme,
                indent: 34,
                isSecondary: true,
                showReplyTarget: true,
                onReply: () => onReply(reply),
              ),
            ),
            if (isExpanded && remaining > 0)
              _RepliesActionButton(
                paddingLeft: 68,
                label: lt(
                  '查看更多回复（剩余 $remaining 条）',
                  'Show more replies ($remaining left)',
                  '返信をさらに表示（残り $remaining 件）',
                ),
                onTap: onLoadMoreReplies,
                theme: theme,
              ),
          ],
          if (!isExpanded && thread.replies.length > replyPreviewCount)
            _RepliesActionButton(
              paddingLeft: 68,
              label: lt(
                '展开 ${thread.replies.length} 条回复',
                'Expand ${thread.replies.length} replies',
                '${thread.replies.length} 件の返信を展開',
              ),
              onTap: onExpand,
              theme: theme,
            )
          else if (isExpanded && thread.replies.length > replyPreviewCount)
            _RepliesActionButton(
              paddingLeft: 68,
              label: lt('收起回复', 'Collapse replies', '返信を閉じる'),
              onTap: onCollapse,
              theme: theme,
            ),
        ],
      ),
    );
  }
}

class _RepliesActionButton extends StatelessWidget {
  const _RepliesActionButton({
    required this.label,
    required this.onTap,
    required this.theme,
    this.paddingLeft = 0,
  });

  final String label;
  final VoidCallback onTap;
  final RaverThemeData theme;
  final double paddingLeft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: paddingLeft, top: 6),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(
          label,
          style: RaverTypography.caption(
            color: theme.secondaryText,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.theme,
    required this.onReply,
    this.indent = 0,
    this.isSecondary = false,
    this.showReplyTarget = false,
  });

  final Comment comment;
  final RaverThemeData theme;
  final VoidCallback onReply;
  final double indent;
  final bool isSecondary;
  final bool showReplyTarget;

  @override
  Widget build(BuildContext context) {
    final avatarRadius = isSecondary ? 12.0 : 16.0;
    final contentText = showReplyTarget && comment.replyToDisplayName.isNotEmpty
        ? lt(
            '回复 ${comment.replyToDisplayName}：${comment.content}',
            'Reply to ${comment.replyToDisplayName}: ${comment.content}',
            '${comment.replyToDisplayName} への返信：${comment.content}',
          )
        : comment.content;

    return Padding(
      padding: EdgeInsets.only(left: indent, top: isSecondary ? 3 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: theme.cardBorder,
            backgroundImage: comment.avatarUrl.isNotEmpty
                ? NetworkImage(comment.avatarUrl)
                : null,
            child: comment.avatarUrl.isEmpty
                ? Icon(
                    Icons.person,
                    size: isSecondary ? 12 : 16,
                    color: theme.secondaryText,
                  )
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
                        size: isSecondary ? 12 : 13,
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
                GestureDetector(
                  onTap: onReply,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    contentText,
                    style: RaverTypography.body(
                      size: isSecondary ? 13 : 14,
                      color: theme.primaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onReply,
                  child: Text(
                    lt('回复', 'Reply', '返信'),
                    style: RaverTypography.body(
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
