import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

import '../data/news_providers.dart';

class NewsDetailScreen extends ConsumerStatefulWidget {
  const NewsDetailScreen({super.key, required this.newsId});

  final String newsId;

  @override
  ConsumerState<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends ConsumerState<NewsDetailScreen> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(newsDetailProvider(widget.newsId).notifier).load());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newsDetailProvider(widget.newsId));
    final theme = context.raver;
    final article = state.article;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        title: Text(lt('资讯详情', 'News Detail', 'ニュース詳細')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: lt('分享', 'Share', '共有'),
            icon: const Icon(Icons.share_outlined),
            onPressed: article == null ? null : () => _shareArticle(article),
          ),
        ],
      ),
      body: _buildBody(state, theme),
    );
  }

  Future<void> _shareArticle(NewsArticle article) async {
    final fallbackUrl = 'https://ravehub.top/n/${article.id}';
    try {
      final payload = await ref
          .read(newsApiProvider)
          .resolveShareLink(article: article, channel: 'system_share');
      final shareUrl = payload.shortUrl.isNotEmpty
          ? payload.shortUrl
          : (payload.url.isNotEmpty ? payload.url : fallbackUrl);
      await ShareService.shareUrl(shareUrl, subject: article.title);
    } catch (_) {
      await ShareService.shareUrl(fallbackUrl, subject: article.title);
    }
  }

  Future<void> _openOriginalLink(String url) async {
    try {
      await UrlLauncherService.openExternalUrl(url);
    } catch (e) {
      if (!mounted) return;
      ToastBanner.show(
        context,
        message: e.toString(),
        type: ToastType.error,
      );
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final success = await ref
        .read(newsDetailProvider(widget.newsId).notifier)
        .submitComment(text);
    if (success) {
      _commentController.clear();
    }
  }

  Widget _buildBody(NewsDetailState state, RaverThemeData theme) {
    if (state.isLoading && state.article == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.article == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.secondaryText),
            const SizedBox(height: 12),
            Text(
              lt('加载失败', 'Failed to load', '読み込みに失敗しました'),
              style: TextStyle(color: theme.primaryText),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  ref.read(newsDetailProvider(widget.newsId).notifier).load(),
              child: Text(lt('重试', 'Retry', '再試行')),
            ),
          ],
        ),
      );
    }

    final article = state.article;
    if (article == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (article.category.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _categoryBadgeColor(article.category)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _categoryTitle(article.category),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _categoryBadgeColor(article.category),
                    ),
                  ),
                ),
              if (article.source.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  article.source,
                  style: TextStyle(fontSize: 12, color: theme.secondaryText),
                ),
              ],
              const Spacer(),
              Icon(Icons.chat_bubble_outline,
                  size: 14, color: theme.secondaryText),
              const SizedBox(width: 4),
              Text(
                '${article.replyCount}',
                style: TextStyle(fontSize: 12, color: theme.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            article.createdAt.length > 16
                ? article.createdAt.substring(0, 16)
                : article.createdAt,
            style: TextStyle(fontSize: 10, color: theme.secondaryText),
          ),
          const SizedBox(height: 16),
          _newsCover(article, theme),
          if (article.summary.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              article.summary,
              style: TextStyle(fontSize: 16, color: theme.primaryText),
            ),
          ],
          if (article.body.isNotEmpty) ...[
            const SizedBox(height: 16),
            _MarkdownBody(markdown: article.body, theme: theme),
          ],
          if (article.link != null && article.link!.isNotEmpty) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _openOriginalLink(article.link!),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new, size: 16, color: theme.accent),
                    const SizedBox(width: 4),
                    Text(
                      lt('查看原文链接', 'View original link', '原文リンクを見る'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (state.hasBoundEntities) ...[
            const SizedBox(height: 16),
            _relatedEntitySection(state, theme),
          ],
          const SizedBox(height: 24),
          InkWell(
            onTap: article.authorId.isEmpty
                ? null
                : () => context.push('/users/${article.authorId}'),
            borderRadius: BorderRadius.circular(10),
            child: _AuthorSection(
              authorName: article.authorName,
              avatarUrl: article.authorAvatarUrl,
              theme: theme,
            ),
          ),
          const SizedBox(height: 18),
          _commentsSection(state, theme),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _commentsSection(NewsDetailState state, RaverThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: theme.cardBorder),
        const SizedBox(height: 12),
        Text(
          lt('评论', 'Comments', 'コメント'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.primaryText,
          ),
        ),
        if (state.commentErrorMessage != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              state.commentErrorMessage!,
              style: TextStyle(fontSize: 12, color: Colors.red.shade300),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (state.isLoadingComments && state.comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator.adaptive()),
          )
        else if (state.comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              lt(
                '还没有评论，来抢沙发吧。',
                'No comments yet. Be the first.',
                'コメントはまだありません。',
              ),
              style: TextStyle(fontSize: 14, color: theme.secondaryText),
            ),
          )
        else
          Column(
            children: [
              for (final comment in state.visibleComments)
                _NewsCommentTile(comment: comment, theme: theme),
              if (state.canRevealMoreComments)
                TextButton(
                  onPressed: () => ref
                      .read(newsDetailProvider(widget.newsId).notifier)
                      .revealMoreComments(),
                  child: Text(lt('加载更多评论', 'Load more comments', 'もっと見る')),
                ),
            ],
          ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: TextStyle(color: theme.primaryText),
                decoration: InputDecoration(
                  hintText: lt('说点什么...', 'Write a comment...', 'コメントを書く...'),
                  hintStyle: TextStyle(color: theme.secondaryText),
                  filled: true,
                  fillColor: theme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: state.isSendingComment ? null : _sendComment,
              style: TextButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: state.isSendingComment
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(lt('发送', 'Send', '送信')),
            ),
          ],
        ),
      ],
    );
  }

  Color _categoryBadgeColor(String category) {
    switch (category) {
      case 'festival':
        return const Color.fromRGBO(245, 133, 51, 1);
      case 'scene':
        return const Color.fromRGBO(89, 171, 245, 1);
      case 'gear':
        return const Color.fromRGBO(102, 201, 97, 1);
      case 'industry':
        return const Color.fromRGBO(222, 135, 74, 1);
      case 'community':
        return const Color.fromRGBO(179, 140, 235, 1);
      default:
        return Colors.grey;
    }
  }

  Widget _newsCover(NewsArticle article, RaverThemeData theme) {
    final url = article.coverImageUrl?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: url.isEmpty
            ? _newsCoverFallback(theme, icon: Icons.newspaper)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => _newsCoverFallback(theme),
                errorWidget: (_, __, ___) =>
                    _newsCoverFallback(theme, icon: Icons.broken_image),
              ),
      ),
    );
  }

  Widget _newsCoverFallback(
    RaverThemeData theme, {
    IconData icon = Icons.newspaper,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F2A39), Color(0xFF2E4866)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, size: 32, color: Colors.white.withValues(alpha: 0.9)),
      ),
    );
  }

  String _categoryTitle(String category) {
    switch (category) {
      case 'festival':
        return lt('电音节', 'Festival', 'フェス');
      case 'scene':
        return lt('现场观察', 'Live Scene', '現場観察');
      case 'gear':
        return lt('设备玩法', 'Gear', '機材');
      case 'industry':
        return lt('行业动态', 'Industry', '業界動向');
      case 'community':
        return lt('社区话题', 'Community', 'コミュニティ');
      default:
        return category;
    }
  }

  Widget _relatedEntitySection(NewsDetailState state, RaverThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.link, size: 14, color: theme.secondaryText),
            const SizedBox(width: 6),
            Text(
              lt('关联实体', 'Related', '関連エンティティ'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.secondaryText,
              ),
            ),
            if (state.isLoadingBindings) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final dj in state.relatedDjs) ...[
                _RelatedEntityChip(
                  icon: Icons.person_outline,
                  label: dj.name,
                  avatarUrl: dj.avatarUrl,
                  onTap: () => context.push('/djs/${dj.id}'),
                ),
                const SizedBox(width: 8),
              ],
              for (final id in state.unresolvedBoundDjIds) ...[
                _RelatedEntityChip(
                  icon: Icons.person_outline,
                  label: 'DJ ${_shortIdLabel(id)}',
                  onTap: () => context.push('/djs/$id'),
                ),
                const SizedBox(width: 8),
              ],
              for (final event in state.relatedEvents) ...[
                _RelatedEntityChip(
                  icon: Icons.calendar_today,
                  label: event.name,
                  onTap: () => context.push('/events/${event.id}'),
                ),
                const SizedBox(width: 8),
              ],
              for (final id in state.unresolvedBoundEventIds) ...[
                _RelatedEntityChip(
                  icon: Icons.calendar_today,
                  label: 'Event ${_shortIdLabel(id)}',
                  onTap: () => context.push('/events/$id'),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _shortIdLabel(String id) {
    final trimmed = id.trim();
    if (trimmed.length <= 6) return '#$trimmed';
    return '#${trimmed.substring(0, 6)}';
  }
}

class _RelatedEntityChip extends StatelessWidget {
  const _RelatedEntityChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.avatarUrl,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatarUrl != null && avatarUrl!.isNotEmpty)
              ClipOval(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: RemoteCoverImage(url: avatarUrl!, fit: BoxFit.cover),
                ),
              )
            else
              Icon(icon, size: 16, color: theme.secondaryText),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsCommentTile extends StatelessWidget {
  const _NewsCommentTile({required this.comment, required this.theme});

  final Comment comment;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: comment.userId.isEmpty
          ? null
          : () => context.push('/users/${comment.userId}'),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 15,
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
                  Text(
                    comment.displayName.isEmpty
                        ? lt('匿名用户', 'Anonymous', '匿名')
                        : comment.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.content,
                    style: TextStyle(fontSize: 14, color: theme.primaryText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCommentTime(comment.createdAt),
                    style: TextStyle(fontSize: 11, color: theme.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCommentTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return lt('刚刚', 'Just now', 'たった今');
    if (diff.inHours < 1) {
      return lt('${diff.inMinutes}分钟前', '${diff.inMinutes}m ago',
          '${diff.inMinutes}分前');
    }
    if (diff.inDays < 1) {
      return lt(
          '${diff.inHours}小时前', '${diff.inHours}h ago', '${diff.inHours}時間前');
    }
    if (diff.inDays < 7) {
      return lt('${diff.inDays}天前', '${diff.inDays}d ago', '${diff.inDays}日前');
    }
    return iso.length > 10 ? iso.substring(0, 10) : iso;
  }
}

class _AuthorSection extends StatelessWidget {
  const _AuthorSection({
    required this.authorName,
    required this.avatarUrl,
    required this.theme,
  });

  final String authorName;
  final String? avatarUrl;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 34,
              height: 34,
              child: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            authorName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: theme.cardBorder,
      child: Icon(Icons.person, size: 20, color: theme.secondaryText),
    );
  }
}

class _MarkdownBody extends StatelessWidget {
  const _MarkdownBody({required this.markdown, required this.theme});

  final String markdown;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    final paragraphs = markdown.split(RegExp(r'\n\n+'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.where((p) => p.trim().isNotEmpty).map((p) {
        final trimmed = p.trim();
        if (trimmed.startsWith('#')) {
          return _buildHeading(trimmed);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            trimmed,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: theme.primaryText,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeading(String line) {
    var level = 0;
    for (final ch in line.characters) {
      if (ch == '#') {
        level++;
      } else {
        break;
      }
    }
    final text = line.substring(level).trim();
    final fontSize = level <= 1
        ? 20.0
        : level == 2
            ? 18.0
            : 16.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: theme.primaryText,
        ),
      ),
    );
  }
}
