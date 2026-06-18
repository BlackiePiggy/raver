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

class DiscoverHomeScreen extends StatefulWidget {
  const DiscoverHomeScreen({super.key});

  @override
  State<DiscoverHomeScreen> createState() => _DiscoverHomeScreenState();
}

class _DiscoverHomeScreenState extends State<DiscoverHomeScreen> {
  static List<String> get _tabTitles => [
        lt('推荐', 'Picks', 'おすすめ'),
        lt('活动', 'Events', 'イベント'),
        lt('资讯', 'News', 'ニュース'),
        lt('主办方', 'Organizers', '主催'),
        'DJ',
        lt('厂牌', 'Labels', 'レーベル'),
        lt('榜单', 'Rankings', 'ランキング'),
        'Sets',
        lt('流派', 'Genres', 'ジャンル'),
      ];

  static const _tabColors = [
    Color(0xFF45D9D1),
    Color(0xFFF78A36),
    Color(0xFFFA9E38),
    Color(0xFFE36394),
    Color(0xFF70C755),
    Color(0xFF6B91F5),
    Color(0xFFC278F2),
    Color(0xFF4DAAF8),
    Color(0xFF3DCAA9),
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

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        bottom: false,
        child: RaverScrollableTabPager(
          tabs: _tabTitles,
          pages: _pages,
          indicatorColors: _tabColors,
          showsDivider: false,
          tabSpacing: 24,
        ),
      ),
    );
  }
}
