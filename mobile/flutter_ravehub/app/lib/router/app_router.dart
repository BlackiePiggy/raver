import 'package:feature_auth/feature_auth.dart';
import 'package:feature_circle/feature_circle.dart';
import 'package:feature_discover/feature_discover.dart';
import 'package:feature_inbox/feature_inbox.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ravehub/router/deep_link_handler.dart';
import 'package:ravehub/router/route_guards.dart';
import 'package:ravehub/shell/raver_shell_scaffold.dart';

// ---------------------------------------------------------------------------
// Tab indices -- keep in sync with the StatefulShellRoute branches.
// ---------------------------------------------------------------------------

/// Index constants for the bottom navigation tabs.
abstract final class TabIndex {
  static const int discover = 0;
  static const int circle = 1;
  static const int inbox = 2;
  static const int profile = 3;
}

// ---------------------------------------------------------------------------
// Navigator keys
// ---------------------------------------------------------------------------

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _discoverNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'discover');
final _circleNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'circle');
final _inboxNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'inbox');
final _profileNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'profile');

// ---------------------------------------------------------------------------
// Helper: attach parentNavigatorKey to a list of routes
// ---------------------------------------------------------------------------

/// Returns a copy of each [GoRoute] in [routes] with its
/// [GoRoute.parentNavigatorKey] set to [key].
///
/// Non-[GoRoute] entries (e.g. [ShellRoute]) are returned unchanged because
/// they manage their own navigator keys.
List<RouteBase> _withParentKey(
  List<RouteBase> routes,
  GlobalKey<NavigatorState> key,
) {
  return routes.map((route) {
    if (route is GoRoute) {
      return GoRoute(
        path: route.path,
        name: route.name,
        parentNavigatorKey: key,
        builder: route.builder,
        pageBuilder: route.pageBuilder,
        redirect: route.redirect,
        routes: route.routes,
      );
    }
    return route;
  }).toList();
}

// ---------------------------------------------------------------------------
// Router factory
// ---------------------------------------------------------------------------

/// Creates the application's [GoRouter] with the full route tree.
///
/// The router uses [StatefulShellRoute.indexedStack] to persist tab state
/// across navigation, and a global [authRedirectGuard] for protecting
/// authenticated routes.
///
/// ## Route structure
///
/// ```
/// /                           -> redirect to /discover
/// /login                      -> Login screen
/// /register                   -> Registration screen
/// /verify-code                -> SMS verification
/// /forgot-password            -> Password reset
/// /discover                   -> Discover tab (shell)
/// /circle                     -> Circle tab (shell)
/// /inbox                      -> Inbox tab (shell)
/// /profile                    -> Profile tab (shell)
/// /events/:eventId            -> Event detail (over shell)
/// /djs/:djId                  -> DJ detail (over shell)
/// /sets/:setId                -> Set detail (over shell)
/// /news/:newsId               -> News article (over shell)
/// /labels/:labelId            -> Label detail (over shell)
/// /festivals/:festivalId      -> Festival detail (over shell)
/// /rankings/:boardId          -> Ranking detail (over shell)
/// /genres/:genreId            -> Genre detail (over shell)
/// /search                     -> Global search (over shell)
/// /users/:userId              -> User profile (over shell)
/// /circle/post/:postId        -> Post detail (over shell)
/// /circle/squads/:squadId     -> Squad detail (over shell)
/// /inbox/alerts/:categoryId   -> Alert category (over shell)
/// /profile/edit               -> Edit profile (over shell)
/// /profile/settings           -> Settings (over shell)
/// ... etc.
/// ```
GoRouter createRouter(Ref ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/discover',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // First, check for deep link URI conversion.
      final uri = state.uri;
      final appPath = DeepLinkHandler.toAppPath(uri);
      if (appPath != null && appPath != state.matchedLocation) {
        return appPath;
      }

      // Then apply the auth redirect guard.
      return authRedirectGuard(context, state);
    },
    routes: [
      // ------------------------------------------------------------------
      // Root redirect
      // ------------------------------------------------------------------
      GoRoute(
        path: '/',
        redirect: (_, __) => '/discover',
      ),

      // ------------------------------------------------------------------
      // Authentication routes (outside shell)
      // ------------------------------------------------------------------
      ..._withParentKey(buildAuthRoutes(), _rootNavigatorKey),

      // ------------------------------------------------------------------
      // Main app shell with bottom tab bar
      // ------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state, navigationShell) {
          return RaverShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          // ---- Discover tab ----
          StatefulShellBranch(
            navigatorKey: _discoverNavigatorKey,
            routes: buildDiscoverRoutes(),
          ),

          // ---- Circle tab ----
          StatefulShellBranch(
            navigatorKey: _circleNavigatorKey,
            routes: buildCircleRoutes(),
          ),

          // ---- Inbox tab ----
          StatefulShellBranch(
            navigatorKey: _inboxNavigatorKey,
            routes: buildInboxRoutes(),
          ),

          // ---- Profile tab ----
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: buildProfileRoutes(),
          ),
        ],
      ),

      // ------------------------------------------------------------------
      // Detail routes presented over the shell (full-screen, no tab bar)
      // ------------------------------------------------------------------

      // Discover detail routes (events, DJs, sets, news, labels, etc.)
      ..._withParentKey(buildDiscoverDetailRoutes(), _rootNavigatorKey),

      // Circle detail routes (posts, squads, IDs, ratings)
      ..._withParentKey(buildCircleDetailRoutes(), _rootNavigatorKey),

      // Inbox detail routes (alert categories, followed entities, etc.)
      ..._withParentKey(buildInboxDetailRoutes(), _rootNavigatorKey),

      // Profile detail routes (user profiles, settings, tools, etc.)
      ..._withParentKey(buildProfileDetailRoutes(), _rootNavigatorKey),
    ],
  );
}
