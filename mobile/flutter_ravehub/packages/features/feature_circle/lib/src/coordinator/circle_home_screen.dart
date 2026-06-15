import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../feed/presentation/feed_screen.dart';
import '../squads/presentation/squad_hall_screen.dart';
import '../ids/presentation/circle_id_hub_screen.dart';
import '../ratings/presentation/rating_hub_screen.dart';

/// Home screen for the Circle tab.
///
/// Contains a scrollable tab pager with 4 sub-tabs:
/// Feed, Squads, ID, Ratings.
class CircleHomeScreen extends StatelessWidget {
  const CircleHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RaverScrollableTabPager(
          tabs: [
            lt('动态', 'Feed', 'フィード'),
            lt('小队', 'Squads', 'スクワッド'),
            lt('ID', 'ID', 'ID'),
            lt('评分', 'Ratings', '評価'),
          ],
          pages: const [
            FeedScreen(),
            SquadHallScreen(),
            CircleIdHubScreen(),
            RatingHubScreen(),
          ],
        ),
      ),
    );
  }
}
