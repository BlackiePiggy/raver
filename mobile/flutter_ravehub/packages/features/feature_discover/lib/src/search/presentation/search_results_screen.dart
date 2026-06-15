import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../../_shared/discover_service_locator.dart';
import 'search_results_view_model.dart';
import 'widgets/search_result_card.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key, required this.initialQuery});

  final String initialQuery;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen>
    with SingleTickerProviderStateMixin {
  late final GlobalSearchResultsViewModel _viewModel;
  late final TabController _tabController;
  final TextEditingController _queryController = TextEditingController();

  static const _tabs = GlobalSearchTab.values;

  @override
  void initState() {
    super.initState();
    _viewModel = GlobalSearchResultsViewModel(
      initialQuery: widget.initialQuery,
      repository: DiscoverServiceLocator.searchRepository,
    );
    _tabController = TabController(length: _tabs.length, vsync: this);
    _queryController.text = widget.initialQuery;
    _viewModel.addListener(_rebuild);
    _viewModel.loadInitial();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _tabController.dispose();
    _queryController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    DiscoverServiceLocator.recentSearchStore.record(query);
    _viewModel.submitSearch(query);
    _tabController.animateTo(0);
  }

  void _onItemTap(GlobalSearchItem item) {
    final route = _routeForItem(item);
    if (route != null) {
      context.push(route);
    }
  }

  String? _routeForItem(GlobalSearchItem item) => switch (item.type) {
        GlobalSearchItemType.event => '/events/${item.entityId}',
        GlobalSearchItemType.dj => '/djs/${item.entityId}',
        GlobalSearchItemType.set => '/sets/${item.entityId}',
        GlobalSearchItemType.news => '/news/${item.entityId}',
        GlobalSearchItemType.label => '/labels/${item.entityId}',
        GlobalSearchItemType.festival => '/festivals/${item.entityId}',
        GlobalSearchItemType.rankingBoard ||
        GlobalSearchItemType.rankingEntry =>
          '/rankings/${item.entityId}',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        title: _buildSearchField(theme),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: theme.accent),
            onPressed: _onSubmit,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(theme),
          Expanded(child: _buildTabContent(theme)),
        ],
      ),
    );
  }

  Widget _buildSearchField(RaverThemeData theme) {
    return TextField(
      controller: _queryController,
      style: RaverTypography.body(size: 16, color: theme.primaryText),
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: lt('搜索…', 'Search…', '検索…'),
        hintStyle: RaverTypography.body(
          size: 16,
          color: theme.secondaryText,
        ),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _onSubmit(),
    );
  }

  Widget _buildTabBar(RaverThemeData theme) {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: theme.primaryText,
      unselectedLabelColor: theme.secondaryText,
      indicatorColor: theme.accent,
      indicatorWeight: 2.5,
      labelStyle: RaverTypography.label(
        size: 13,
        color: theme.primaryText,
        weight: FontWeight.w600,
      ),
      unselectedLabelStyle: RaverTypography.label(
        size: 13,
        color: theme.secondaryText,
        weight: FontWeight.w400,
      ),
      tabs: _tabs.map((tab) {
        final count = _viewModel.countForTab(tab);
        final label = _tabLabel(tab);
        return Tab(
          text: count > 0 ? '$label ($count)' : label,
        );
      }).toList(),
    );
  }

  Widget _buildTabContent(RaverThemeData theme) {
    return TabBarView(
      controller: _tabController,
      children: _tabs.map((tab) {
        final phase = _viewModel.phaseByTab[tab] ?? SearchLoadPhase.idle;

        return switch (phase) {
          SearchLoadPhase.idle || SearchLoadPhase.loading =>
            const SearchSkeleton(),
          SearchLoadPhase.failed => _buildErrorState(tab, theme),
          SearchLoadPhase.empty => _buildEmptyState(theme),
          SearchLoadPhase.loaded => tab == GlobalSearchTab.all
              ? _buildAllTabContent(theme)
              : _buildDomainTabContent(tab, theme),
        };
      }).toList(),
    );
  }

  Widget _buildAllTabContent(RaverThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryStrip(theme),
        const SizedBox(height: 12),
        if (_viewModel.topMatches.isNotEmpty) ...[
          Text(
            lt('最佳匹配', 'Top Matches', 'ベストマッチ'),
            style: RaverTypography.title(size: 16, color: theme.primaryText),
          ),
          const SizedBox(height: 8),
          ..._viewModel.topMatches.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SearchResultCard(
                item: item,
                onTap: () => _onItemTap(item),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ..._viewModel.previewTabs.map((tab) {
          final items = _viewModel.itemsForTab(tab).take(3).toList();
          if (items.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _iconForTab(tab),
                    size: 16,
                    color: _colorForTab(tab),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _tabLabel(tab),
                    style: RaverTypography.label(
                      size: 14,
                      color: theme.primaryText,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_viewModel.countForTab(tab)}',
                    style: RaverTypography.caption(
                      color: theme.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SearchResultCard(
                    item: item,
                    onTap: () => _onItemTap(item),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildDomainTabContent(GlobalSearchTab tab, RaverThemeData theme) {
    final items = _viewModel.itemsForTab(tab);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return SearchResultCard(
          item: item,
          onTap: () => _onItemTap(item),
        );
      },
    );
  }

  Widget _buildSummaryStrip(RaverThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: theme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lt(
                '找到与 "${_viewModel.query}" 相关的内容',
                'Results for "${_viewModel.query}"',
                '「${_viewModel.query}」の検索結果',
              ),
              style: RaverTypography.label(
                size: 14,
                color: theme.primaryText,
                weight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_viewModel.allItems.length}',
              style: RaverTypography.caption(
                color: Colors.white,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(RaverThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 34,
              color: theme.accent,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            lt('没有找到相关内容', 'No Results Found', '関連内容が見つかりません'),
            style: RaverTypography.title(size: 18, color: theme.primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            lt('换个关键词试试', 'Try another keyword', '別のキーワードを試してください'),
            style: RaverTypography.body(
              size: 14,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(GlobalSearchTab tab, RaverThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off, size: 32, color: Colors.orange),
          ),
          const SizedBox(height: 12),
          Text(
            _viewModel.errorMessage ??
                lt('搜索失败', 'Search Failed', '検索に失敗しました'),
            style: RaverTypography.body(
              size: 14,
              color: theme.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _viewModel.retryTab(tab),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    lt('重试', 'Retry', '再試行'),
                    style: RaverTypography.label(
                      size: 14,
                      color: Colors.white,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _tabLabel(GlobalSearchTab tab) => switch (tab) {
        GlobalSearchTab.all => lt('全部', 'All', 'すべて'),
        GlobalSearchTab.events => lt('活动', 'Events', 'イベント'),
        GlobalSearchTab.djs => 'DJ',
        GlobalSearchTab.peopleSquads =>
          lt('用户/小队', 'People', 'ユーザー'),
        GlobalSearchTab.posts => lt('圈子', 'Posts', '投稿'),
        GlobalSearchTab.news => lt('资讯', 'News', 'ニュース'),
        GlobalSearchTab.sets => 'Sets',
        GlobalSearchTab.rankings =>
          lt('榜单', 'Rankings', 'ランキング'),
        GlobalSearchTab.ratings => lt('打分', 'Ratings', '評価'),
        GlobalSearchTab.festivals =>
          lt('品牌', 'Brands', 'ブランド'),
        GlobalSearchTab.labels =>
          lt('厂牌', 'Labels', 'レーベル'),
        GlobalSearchTab.genreTree =>
          lt('风格树', 'Genres', 'ジャンル'),
      };

  static IconData _iconForTab(GlobalSearchTab tab) => switch (tab) {
        GlobalSearchTab.all => Icons.apps,
        GlobalSearchTab.events => Icons.calendar_today,
        GlobalSearchTab.djs => Icons.headphones,
        GlobalSearchTab.peopleSquads => Icons.people,
        GlobalSearchTab.posts => Icons.chat_bubble_outline,
        GlobalSearchTab.news => Icons.article,
        GlobalSearchTab.sets => Icons.play_circle_outline,
        GlobalSearchTab.rankings => Icons.format_list_numbered,
        GlobalSearchTab.ratings => Icons.star,
        GlobalSearchTab.festivals => Icons.auto_awesome,
        GlobalSearchTab.labels => Icons.label,
        GlobalSearchTab.genreTree => Icons.park,
      };

  static Color _colorForTab(GlobalSearchTab tab) => switch (tab) {
        GlobalSearchTab.all => const Color(0xFF6B42DB),
        GlobalSearchTab.events => const Color(0xFFF88A35),
        GlobalSearchTab.djs => const Color(0xFF70C754),
        GlobalSearchTab.peopleSquads => const Color(0xFFF57347),
        GlobalSearchTab.posts => const Color(0xFFF24D61),
        GlobalSearchTab.news => const Color(0xFFFB9E38),
        GlobalSearchTab.sets => const Color(0xFF4DABF7),
        GlobalSearchTab.rankings => const Color(0xFFFAB538),
        GlobalSearchTab.ratings => const Color(0xFFEB6BCC),
        GlobalSearchTab.festivals => const Color(0xFFC278F2),
        GlobalSearchTab.labels => const Color(0xFF9E80EB),
        GlobalSearchTab.genreTree => const Color(0xFF3DB3C7),
      };
}
