import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../data/news_providers.dart';

class NewsListScreen extends ConsumerStatefulWidget {
  const NewsListScreen({super.key});

  @override
  ConsumerState<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends ConsumerState<NewsListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(newsListProvider.notifier).loadIfNeeded());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    final state = ref.watch(newsListProvider);
    final theme = context.raver;

    return RaverTabReselectionListener(
      tabIndex: 0,
      onReselected: _scrollToTop,
      child: Column(
        children: [
          _CategoryFilterRow(
            selected: state.selectedCategory,
            onSelected: (c) =>
                ref.read(newsListProvider.notifier).setCategory(c),
            onPublish: _openNewsEditor,
            theme: theme,
          ),
          Expanded(
            child: _buildContent(state, theme),
          ),
        ],
      ),
    );
  }

  Future<void> _openNewsEditor() async {
    final didChange = await context.push<bool>('/news/new');
    if (didChange == true && mounted) {
      await ref.read(newsListProvider.notifier).reload();
    }
  }

  Widget _buildContent(NewsListState state, RaverThemeData theme) {
    if (!state.hasLoaded && state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.secondaryText),
            const SizedBox(height: 12),
            Text(
              lt('资讯加载失败', 'Failed to load news', 'ニュースの読み込みに失敗しました'),
              style: TextStyle(color: theme.primaryText, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.read(newsListProvider.notifier).reload(),
              child: Text(lt('重试', 'Retry', '再試行')),
            ),
          ],
        ),
      );
    }

    if (state.hasLoaded && state.displayedArticles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.newspaper, size: 48, color: theme.secondaryText),
            const SizedBox(height: 12),
            Text(
              lt('暂无资讯', 'No news yet', 'ニュースはまだありません'),
              style: TextStyle(color: theme.secondaryText, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(newsListProvider.notifier).reload(),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: state.displayedArticles.length + (state.canLoadMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            Divider(height: 1, indent: 16, color: theme.cardBorder),
        itemBuilder: (context, index) {
          if (index >= state.displayedArticles.length) {
            Future.microtask(
                () => ref.read(newsListProvider.notifier).loadMore());
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final article = state.displayedArticles[index];
          return _NewsCard(
            article: article,
            onTap: () => context.push('/news/${article.id}'),
          );
        },
      ),
    );
  }
}

class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow({
    required this.selected,
    required this.onSelected,
    required this.onPublish,
    required this.theme,
  });

  final NewsCategory selected;
  final ValueChanged<NewsCategory> onSelected;
  final VoidCallback onPublish;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: theme.background,
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16),
              itemCount: NewsCategory.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = NewsCategory.values[index];
                final isSelected = category == selected;
                return GestureDetector(
                  onTap: () => onSelected(category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? _categoryColor(category) : theme.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _categoryTitle(category),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : theme.primaryText,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Tooltip(
              message: lt('发布资讯', 'Publish News', 'ニュース投稿'),
              child: InkWell(
                onTap: onPublish,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(245, 130, 46, 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(NewsCategory category) {
    switch (category) {
      case NewsCategory.all:
        return theme.secondaryText;
      case NewsCategory.festival:
        return const Color.fromRGBO(245, 133, 51, 1);
      case NewsCategory.scene:
        return const Color.fromRGBO(89, 171, 245, 1);
      case NewsCategory.gear:
        return const Color.fromRGBO(102, 201, 97, 1);
      case NewsCategory.industry:
        return const Color.fromRGBO(222, 135, 74, 1);
      case NewsCategory.community:
        return const Color.fromRGBO(179, 140, 235, 1);
    }
  }

  String _categoryTitle(NewsCategory category) {
    switch (category) {
      case NewsCategory.all:
        return lt('全部', 'All', 'すべて');
      case NewsCategory.festival:
        return lt('电音节', 'Festival', 'フェス');
      case NewsCategory.scene:
        return lt('现场观察', 'Live Scene', '現場観察');
      case NewsCategory.gear:
        return lt('设备玩法', 'Gear', '機材');
      case NewsCategory.industry:
        return lt('行业动态', 'Industry', '業界動向');
      case NewsCategory.community:
        return lt('社区话题', 'Community', 'コミュニティ');
    }
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.article, required this.onTap});

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (article.category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
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
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            article.source,
                            style: TextStyle(
                                fontSize: 10, color: theme.secondaryText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    article.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        article.createdAt.length > 10
                            ? article.createdAt.substring(0, 10)
                            : article.createdAt,
                        style:
                            TextStyle(fontSize: 10, color: theme.secondaryText),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.chat_bubble_outline,
                          size: 12, color: theme.secondaryText),
                      const SizedBox(width: 3),
                      Text(
                        '${article.replyCount}',
                        style:
                            TextStyle(fontSize: 10, color: theme.secondaryText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 122,
                height: 82,
                child: article.coverImageUrl != null &&
                        article.coverImageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: article.coverImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _coverFallback(theme),
                        errorWidget: (_, __, ___) => _coverFallback(theme),
                      )
                    : _coverFallback(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback(RaverThemeData theme) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF232B35), Color(0xFF1C2128)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.newspaper, color: theme.secondaryText, size: 24),
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
