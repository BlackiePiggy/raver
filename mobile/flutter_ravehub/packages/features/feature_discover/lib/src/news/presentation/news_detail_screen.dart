import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../data/news_providers.dart';

class NewsDetailScreen extends ConsumerStatefulWidget {
  const NewsDetailScreen({super.key, required this.newsId});

  final String newsId;

  @override
  ConsumerState<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends ConsumerState<NewsDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(newsDetailProvider(widget.newsId).notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newsDetailProvider(widget.newsId));
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        title: Text(lt('资讯详情', 'News Detail', 'ニュース詳細')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(state, theme),
    );
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
          if (article.coverImageUrl != null &&
              article.coverImageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: article.coverImageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: theme.card,
                    child: Center(
                      child: Icon(Icons.newspaper,
                          size: 32, color: theme.secondaryText),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: theme.card,
                    child: Center(
                      child: Icon(Icons.broken_image,
                          size: 32, color: theme.secondaryText),
                    ),
                  ),
                ),
              ),
            ),
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
            Row(
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
          ],
          const SizedBox(height: 24),
          _AuthorSection(
            authorName: article.authorName,
            avatarUrl: article.authorAvatarUrl,
            theme: theme,
          ),
          const SizedBox(height: 80),
        ],
      ),
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
                      errorWidget: (_, __, ___) =>
                          _avatarFallback(),
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
      children: paragraphs
          .where((p) => p.trim().isNotEmpty)
          .map((p) {
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
          })
          .toList(),
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
