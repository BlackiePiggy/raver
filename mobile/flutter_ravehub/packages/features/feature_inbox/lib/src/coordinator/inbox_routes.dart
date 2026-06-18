import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../presentation/inbox_home_screen.dart';
import '../presentation/alert_category_screen.dart';
import '../presentation/followed_events_inbox_screen.dart';
import '../presentation/followed_djs_inbox_screen.dart';
import '../presentation/followed_brands_inbox_screen.dart';
import '../presentation/content_reviews_inbox_screen.dart';
import '../presentation/entity_change_detail_screen.dart';
import '../presentation/notification_settings_screen.dart';

/// Primary route for the Inbox tab.
List<RouteBase> buildInboxRoutes() => [
  GoRoute(
    path: '/inbox',
    builder: (BuildContext context, GoRouterState state) =>
        const InboxHomeScreen(),
  ),
];

/// Detail routes reachable from the Inbox tab.
List<RouteBase> buildInboxDetailRoutes() => [
  GoRoute(
    path: '/inbox/alerts/:categoryId',
    builder: (BuildContext context, GoRouterState state) =>
        AlertCategoryScreen(categoryId: state.pathParameters['categoryId']!),
  ),
  GoRoute(
    path: '/inbox/followed-events',
    builder: (BuildContext context, GoRouterState state) =>
        const FollowedEventsInboxScreen(),
  ),
  GoRoute(
    path: '/inbox/followed-djs',
    builder: (BuildContext context, GoRouterState state) =>
        const FollowedDjsInboxScreen(),
  ),
  GoRoute(
    path: '/inbox/followed-brands',
    builder: (BuildContext context, GoRouterState state) =>
        const FollowedBrandsInboxScreen(),
  ),
  GoRoute(
    path: '/inbox/content-reviews',
    builder: (BuildContext context, GoRouterState state) =>
        const ContentReviewsInboxScreen(),
  ),
  GoRoute(
    path: '/inbox/changes/:entityType/:entityId',
    builder: (BuildContext context, GoRouterState state) {
      final extra = state.extra as Map<String, dynamic>? ?? {};
      return EntityChangeDetailScreen(
        entityType: state.pathParameters['entityType']!,
        entityId: state.pathParameters['entityId']!,
        entityName: extra['entityName'] as String? ?? '',
        changeType: extra['changeType'] as String? ?? '',
        summary: extra['summary'] as String? ?? '',
        updateTitle: extra['updateTitle'] as String?,
        targetType: extra['targetType'] as String?,
        targetId: extra['targetId'] as String?,
        imageUrl: extra['imageUrl'] as String?,
      );
    },
  ),
  GoRoute(
    path: '/settings/notifications',
    builder: (BuildContext context, GoRouterState state) =>
        const NotificationSettingsScreen(),
  ),
];
