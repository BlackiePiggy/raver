import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../recommend/presentation/recommend_screen.dart';
import '../events/presentation/events_list_screen.dart';
import '../news/presentation/news_list_screen.dart';
import '../organizers/presentation/organizers_root_screen.dart';
import '../djs/presentation/djs_list_screen.dart';
import '../labels/presentation/labels_root_screen.dart';
import '../rankings/presentation/rankings_root_screen.dart';
import '../sets/presentation/sets_list_screen.dart';
import '../genres_sunburst/presentation/genres_root_screen.dart';
import '../search/presentation/search_overlay_screen.dart';

class DiscoverHomeScreen extends StatefulWidget {
  const DiscoverHomeScreen({super.key});

  @override
  State<DiscoverHomeScreen> createState() => _DiscoverHomeScreenState();
}

class _DiscoverHomeScreenState extends State<DiscoverHomeScreen> {
  static List<String> get _tabTitles => [
        lt('推荐', 'Recommend', 'おすすめ'),
        lt('活动', 'Events', 'イベント'),
        lt('资讯', 'News', 'ニュース'),
        lt('主办方', 'Organizers', '主催者'),
        'DJs',
        lt('厂牌', 'Labels', 'レーベル'),
        lt('榜单', 'Rankings', 'ランキング'),
        'Sets',
        lt('风格', 'Genres', 'ジャンル'),
      ];

  static const _pages = <Widget>[
    RecommendScreen(),
    EventsListScreen(),
    NewsListScreen(),
    OrganizersRootScreen(),
    DjsListScreen(),
    LabelsRootScreen(),
    RankingsRootScreen(),
    SetsListScreen(),
    GenresRootScreen(),
  ];

  void _openSearch(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      pageBuilder: (_, __, ___) => SearchOverlayScreen(
        onDismiss: () => Navigator.of(context).pop(),
      ),
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        title: Text(
          lt('发现', 'Discover', '発見'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: theme.primaryText),
            onPressed: () => _openSearch(context),
          ),
        ],
      ),
      body: RaverScrollableTabPager(
        tabs: _tabTitles,
        pages: _pages,
      ),
    );
  }
}
