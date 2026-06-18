import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../coordinator/circle_home_screen.dart';
import '../feed/presentation/post_detail_screen.dart';
import '../feed/presentation/compose_post_screen.dart';
import '../squads/presentation/squad_profile_screen.dart';
import '../squads/presentation/squad_manage_screen.dart';
import '../squads/presentation/squad_offline_activity_history_screen.dart';
import '../ids/presentation/circle_id_detail_screen.dart';
import '../ratings/presentation/rating_event_detail_screen.dart';
import '../ratings/presentation/rating_unit_detail_screen.dart';

/// Primary route for the Circle tab.
List<RouteBase> buildCircleRoutes() => [
  GoRoute(
    path: '/circle',
    builder: (BuildContext context, GoRouterState state) =>
        const CircleHomeScreen(),
  ),
];

/// Detail routes reachable from the Circle tab.
List<RouteBase> buildCircleDetailRoutes() => [
  // Feed
  GoRoute(
    path: '/circle/post/:postId',
    builder: (BuildContext context, GoRouterState state) =>
        PostDetailScreen(postId: state.pathParameters['postId']!),
  ),
  GoRoute(
    path: '/circle/compose',
    builder: (BuildContext context, GoRouterState state) =>
        const ComposePostScreen(),
  ),

  // Squads
  GoRoute(
    path: '/circle/squads/:squadId',
    builder: (BuildContext context, GoRouterState state) =>
        SquadProfileScreen(squadId: state.pathParameters['squadId']!),
  ),
  GoRoute(
    path: '/circle/squads/:squadId/manage',
    builder: (BuildContext context, GoRouterState state) =>
        SquadManageScreen(squadId: state.pathParameters['squadId']!),
  ),
  GoRoute(
    path: '/circle/squads/:squadId/activities',
    builder: (BuildContext context, GoRouterState state) =>
        SquadOfflineActivityHistoryScreen(
          squadId: state.pathParameters['squadId']!,
        ),
  ),

  // Circle IDs
  GoRoute(
    path: '/circle/ids/:cardId',
    builder: (BuildContext context, GoRouterState state) =>
        CircleIdDetailScreen(cardId: state.pathParameters['cardId']!),
  ),
  GoRoute(
    path: '/circle/id/:cardId',
    builder: (BuildContext context, GoRouterState state) =>
        CircleIdDetailScreen(cardId: state.pathParameters['cardId']!),
  ),

  // Ratings
  GoRoute(
    path: '/circle/ratings/:ratingId',
    builder: (BuildContext context, GoRouterState state) =>
        RatingEventDetailScreen(ratingId: state.pathParameters['ratingId']!),
  ),
  GoRoute(
    path: '/circle/ratings/:ratingId/units/:unitId',
    builder: (BuildContext context, GoRouterState state) =>
        RatingUnitDetailScreen(
          ratingId: state.pathParameters['ratingId']!,
          unitId: state.pathParameters['unitId']!,
        ),
  ),
];
