import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../../_shared/circle_service_locator.dart';
import '../data/circle_id_api.dart';
import 'widgets/circle_id_share_sheet.dart';

class CircleIdDetailScreen extends StatefulWidget {
  const CircleIdDetailScreen({super.key, required this.cardId});

  final String cardId;

  @override
  State<CircleIdDetailScreen> createState() => _CircleIdDetailScreenState();
}

class _CircleIdDetailScreenState extends State<CircleIdDetailScreen> {
  final _commentController = TextEditingController();
  final List<Comment> _comments = [];
  CircleIdCard? _card;
  bool _isLoading = true;
  bool _isLoadingComments = false;
  bool _isPostingComment = false;
  final Set<String> _busyActions = {};
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadCard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _card = await CircleServiceLocator.circleIdRepository.fetchCircleId(
        id: widget.cardId,
      );
      await _loadComments();
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    try {
      final page = await CircleServiceLocator.feedRepository.fetchComments(
        postId: widget.cardId,
        page: 1,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _comments
          ..clear()
          ..addAll(page.items);
      });
    } catch (_) {
      // Comments are secondary to the ID detail payload.
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isPostingComment) return;
    setState(() => _isPostingComment = true);
    try {
      final comment = await CircleServiceLocator.feedRepository.postComment(
        postId: widget.cardId,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _comments.insert(0, comment);
        _commentController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt(
              '评论发送失败，请稍后重试',
              'Failed to send comment. Please try again.',
              'コメントの送信に失敗しました。もう一度お試しください。',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  Future<void> _showShareSheet() async {
    final card = _card;
    if (card == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CircleIdShareSheet(
        card: card,
        onShared: (post) =>
            setState(() => _card = card.withPostInteraction(post)),
      ),
    );
  }

  Future<void> _toggleReaction(_CircleIdReaction reaction) async {
    final card = _card;
    if (card == null || _busyActions.contains(reaction.name)) return;
    setState(() => _busyActions.add(reaction.name));
    try {
      final post = switch (reaction) {
        _CircleIdReaction.like =>
          await CircleServiceLocator.feedRepository.toggleLikePost(
            postId: card.id,
            currentlyLiked: card.isLiked,
          ),
        _CircleIdReaction.favorite =>
          await CircleServiceLocator.feedRepository.toggleFavoritePost(
            postId: card.id,
            currentlySaved: card.isFavorited,
          ),
        _CircleIdReaction.repost =>
          await CircleServiceLocator.feedRepository.toggleRepost(
            postId: card.id,
            currentlyReposted: card.isReposted,
          ),
      };
      if (!mounted) return;
      setState(() => _card = card.withPostInteraction(post));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt(
              '操作失败，请稍后重试',
              'Action failed. Please try again.',
              '操作に失敗しました。もう一度お試しください。',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyActions.remove(reaction.name));
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
          lt('ID详情', 'ID Detail', 'ID詳細'),
          style: RaverTypography.title(size: 17, color: theme.primaryText),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz, color: theme.primaryText),
            onPressed: _showShareSheet,
          ),
        ],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _card == null
          ? ErrorStateView(
              title: lt('加载失败', 'Failed to Load', '読み込みに失敗しました'),
              error: _error,
              onRetry: _loadCard,
              retryLabel: lt('重试', 'Retry', '再試行'),
            )
          : _buildDetail(theme),
    );
  }

  Widget _buildDetail(RaverThemeData theme) {
    final card = _card!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleIdPlayerPreview(card: card, large: true),
          if (card.djs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: card.djs.map(_LinkedDjChip.new).toList(),
            ),
          ],
          if (card.event != null) ...[
            const SizedBox(height: 12),
            _LinkedEventRow(event: card.event!),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _ActionPill(
                icon: card.isLiked ? Icons.favorite : Icons.favorite_border,
                count: card.likeCount,
                isActive: card.isLiked,
                onTap: () => _toggleReaction(_CircleIdReaction.like),
              ),
              const SizedBox(width: 8),
              _ActionPill(
                icon: card.isFavorited ? Icons.star : Icons.star_border,
                count: card.favoriteCount,
                isActive: card.isFavorited,
                onTap: () => _toggleReaction(_CircleIdReaction.favorite),
              ),
              const SizedBox(width: 8),
              _ActionPill(
                icon: Icons.repeat,
                count: card.repostCount,
                isActive: card.isReposted,
                onTap: () => _toggleReaction(_CircleIdReaction.repost),
              ),
              const SizedBox(width: 8),
              _ActionPill(
                icon: Icons.ios_share_outlined,
                count: 0,
                onTap: _showShareSheet,
              ),
              const SizedBox(width: 8),
              _ActionPill(
                icon: Icons.chat_bubble_outline,
                count: card.commentCount,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Avatar(url: card.contributorAvatarUrl, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.contributorName.isEmpty
                          ? lt('贡献者', 'Contributor', '投稿者')
                          : card.contributorName,
                      style: RaverTypography.caption(
                        color: theme.primaryText,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      lt('贡献者', 'Contributor', '投稿者'),
                      style: RaverTypography.caption(
                        size: 11,
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _compactDate(card.createdAt),
                style: RaverTypography.caption(
                  size: 11,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CommentsPanel(
            controller: _commentController,
            comments: _comments,
            isLoading: _isLoadingComments,
            isPosting: _isPostingComment,
            onSend: _postComment,
          ),
        ],
      ),
    );
  }
}

class _CircleIdPlayerPreview extends StatelessWidget {
  const _CircleIdPlayerPreview({required this.card, this.large = false});

  final CircleIdCard card;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final hasVideo = card.videoUrl.isNotEmpty;
    final hasAudio = card.audioUrl.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(large ? 16 : 12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: large ? 58 : 44,
            height: large ? 58 : 44,
            decoration: BoxDecoration(
              color: theme.cardBorder,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasVideo ? Icons.play_circle_fill : Icons.music_note,
              color: theme.accent,
              size: large ? 34 : 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.songName,
                  style: RaverTypography.title(
                    size: large ? 20 : 15,
                    color: theme.primaryText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  hasVideo
                      ? lt('视频 ID', 'Video ID', '動画ID')
                      : hasAudio
                      ? lt('音频 ID', 'Audio ID', '音声ID')
                      : lt('ID 片段', 'ID Clip', 'IDクリップ'),
                  style: RaverTypography.caption(color: theme.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedEventRow extends StatelessWidget {
  const _LinkedEventRow({required this.event});

  final CircleIdLinkedEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          _Thumb(url: event.coverImageUrl, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: RaverTypography.caption(
                    color: theme.primaryText,
                    weight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _compactDate(event.startDate),
                  style: RaverTypography.caption(
                    size: 11,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: theme.secondaryText),
        ],
      ),
    );
  }
}

class _LinkedDjChip extends StatelessWidget {
  const _LinkedDjChip(this.dj);

  final CircleIdLinkedDj dj;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Avatar(url: dj.avatarUrl, size: 24),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              dj.name,
              style: RaverTypography.caption(
                color: theme.primaryText,
                weight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.count,
    this.isActive = false,
    this.onTap,
  });

  final IconData icon;
  final int count;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final foreground = isActive ? theme.accent : theme.primaryText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: (isActive ? theme.accent : theme.cardBorder).withValues(
            alpha: isActive ? 0.14 : 0.42,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: foreground),
            if (count > 0 || icon != Icons.ios_share_outlined) ...[
              const SizedBox(width: 5),
              Text(
                '$count',
                style: RaverTypography.caption(
                  color: foreground,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _CircleIdReaction { like, favorite, repost }

class _CommentsPanel extends StatelessWidget {
  const _CommentsPanel({
    required this.controller,
    required this.comments,
    required this.isLoading,
    required this.isPosting,
    required this.onSend,
  });

  final TextEditingController controller;
  final List<Comment> comments;
  final bool isLoading;
  final bool isPosting;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lt('评论区', 'Comments', 'コメント欄'),
            style: RaverTypography.title(size: 16, color: theme.primaryText),
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else if (comments.isEmpty)
            Text(
              lt(
                '还没有评论，来抢沙发吧。',
                'No comments yet. Be the first to write one.',
                'コメントはまだありません。最初のコメントを書きましょう。',
              ),
              style: RaverTypography.body(size: 14, color: theme.secondaryText),
            )
          else
            ...comments.map((comment) => _CommentTile(comment: comment)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: lt('说点什么...', 'Say something...', '何か書いてください...'),
                    filled: true,
                    fillColor: theme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isPosting ? null : onSend,
                child: isPosting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(lt('发送', 'Send', '送信')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(url: comment.avatarUrl, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.displayName,
                  style: RaverTypography.label(
                    size: 14,
                    color: theme.primaryText,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  comment.content,
                  style: RaverTypography.body(
                    size: 14,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _compactDate(comment.createdAt),
                  style: RaverTypography.caption(
                    size: 11,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    if (url.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: theme.cardBorder,
        child: Icon(Icons.person, size: size * 0.5, color: theme.secondaryText),
      );
    }
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: size / 2,
          backgroundColor: theme.cardBorder,
          child: Icon(
            Icons.person,
            size: size * 0.5,
            color: theme.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.cardBorder,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.event, color: theme.secondaryText, size: size * 0.45),
    );
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}

String _compactDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
}
