import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../_shared/discover_service_locator.dart';
import '../coordinator/discover_home_screen.dart';
import '../events/presentation/event_detail_screen.dart';
import '../events/presentation/event_editor_screen.dart';
import '../events/presentation/event_upload_flow_screen.dart';
import '../events/presentation/event_lineup_import_screen.dart';
import '../events/presentation/event_route_planner_screen.dart';
import '../djs/presentation/dj_detail_screen.dart';
import '../djs/presentation/dj_import_screen.dart';
import '../djs/presentation/dj_editor_screen.dart';
import '../djs/presentation/dj_upload_flow_screen.dart';
import '../sets/presentation/set_detail_screen.dart';
import '../sets/presentation/set_editor_screen.dart';
import '../news/presentation/news_detail_screen.dart';
import '../news/presentation/news_editor_screen.dart';
import '../labels/presentation/label_detail_screen.dart';
import '../organizers/presentation/festival_detail_screen.dart';
import '../organizers/presentation/organizer_upload_flow_screen.dart';
import '../rankings/presentation/ranking_board_detail_screen.dart';
import '../rankings/presentation/ranking_entry_detail_screen.dart';
import '../genres_sunburst/presentation/genre_detail_screen.dart';
import '../search/presentation/search_results_screen.dart';

/// Primary routes for the Discover tab (shown as a top-level destination).
List<RouteBase> buildDiscoverRoutes() => [
      GoRoute(
        path: '/discover',
        builder: (BuildContext context, GoRouterState state) =>
            const DiscoverHomeScreen(),
      ),
    ];

/// Detail routes reachable from anywhere in the app (events, DJs, sets, etc.).
///
/// **Ordering matters!** GoRouter uses first-match routing, so static paths
/// (e.g. `/events/new`) must appear *before* parameterized paths
/// (e.g. `/events/:eventId`), otherwise the literal segment is swallowed
/// as a path parameter.
List<RouteBase> buildDiscoverDetailRoutes() => [
      // -- Events (static before parameterized) ----------------------------
      GoRoute(
        path: '/events/new',
        builder: (BuildContext context, GoRouterState state) =>
            const EventUploadFlowScreen(),
      ),
      GoRoute(
        path: '/events/:eventId',
        builder: (BuildContext context, GoRouterState state) =>
            EventDetailScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(
        path: '/events/:eventId/edit',
        builder: (BuildContext context, GoRouterState state) =>
            EventEditorScreen(eventId: state.pathParameters['eventId']),
      ),
      GoRoute(
        path: '/events/:eventId/route',
        builder: (BuildContext context, GoRouterState state) {
          final params = state.uri.queryParameters;
          return EventRoutePlannerScreen(
            eventId: state.pathParameters['eventId']!,
            venueName: params['venueName'] ?? '',
            latitude: double.tryParse(params['lat'] ?? '') ?? 0,
            longitude: double.tryParse(params['lng'] ?? '') ?? 0,
          );
        },
      ),
      GoRoute(
        path: '/events/:eventId/lineup/import',
        builder: (BuildContext context, GoRouterState state) =>
            EventLineupImportScreen(
          eventId: state.pathParameters['eventId'],
        ),
      ),

      // -- DJs (static before parameterized) -------------------------------
      GoRoute(
        path: '/djs/import',
        builder: (BuildContext context, GoRouterState state) =>
            DjImportScreen(djApi: DiscoverServiceLocator.djApi),
      ),
      GoRoute(
        path: '/djs/new',
        builder: (BuildContext context, GoRouterState state) =>
            const DjUploadFlowScreen(),
      ),
      GoRoute(
        path: '/djs/:djId',
        builder: (BuildContext context, GoRouterState state) =>
            DjDetailScreen(djId: state.pathParameters['djId']!),
      ),
      GoRoute(
        path: '/djs/:djId/edit',
        builder: (BuildContext context, GoRouterState state) => DjEditorScreen(
          djId: state.pathParameters['djId'],
          djApi: DiscoverServiceLocator.djApi,
        ),
      ),

      // -- Sets (static before parameterized) ------------------------------
      GoRoute(
        path: '/sets/new',
        builder: (BuildContext context, GoRouterState state) =>
            SetEditorScreen(setApi: DiscoverServiceLocator.setApi),
      ),
      GoRoute(
        path: '/sets/:setId/tracklist/edit',
        builder: (BuildContext context, GoRouterState state) => SetEditorScreen(
          setId: state.pathParameters['setId'],
          setApi: DiscoverServiceLocator.setApi,
          openTracklistOnLoad: true,
        ),
      ),
      GoRoute(
        path: '/sets/:setId',
        builder: (BuildContext context, GoRouterState state) =>
            SetDetailScreen(setId: state.pathParameters['setId']!),
      ),
      GoRoute(
        path: '/sets/:setId/edit',
        builder: (BuildContext context, GoRouterState state) => SetEditorScreen(
          setId: state.pathParameters['setId'],
          setApi: DiscoverServiceLocator.setApi,
        ),
      ),

      // -- News (static before parameterized) ------------------------------
      GoRoute(
        path: '/news/new',
        builder: (BuildContext context, GoRouterState state) =>
            const NewsEditorScreen(),
      ),
      GoRoute(
        path: '/news/:newsId',
        builder: (BuildContext context, GoRouterState state) =>
            NewsDetailScreen(
          newsId: state.pathParameters['newsId']!,
        ),
      ),
      GoRoute(
        path: '/news/:newsId/edit',
        builder: (BuildContext context, GoRouterState state) =>
            NewsEditorScreen(articleId: state.pathParameters['newsId']),
      ),

      // -- Labels (no static variants) -------------------------------------
      GoRoute(
        path: '/labels/:labelId',
        builder: (BuildContext context, GoRouterState state) =>
            LabelDetailScreen(
          labelId: state.pathParameters['labelId']!,
        ),
      ),

      // -- Festivals (static before parameterized) -------------------------
      GoRoute(
        path: '/festivals/new',
        builder: (BuildContext context, GoRouterState state) =>
            const OrganizerUploadFlowScreen(),
      ),
      GoRoute(
        path: '/festivals/:festivalId',
        builder: (BuildContext context, GoRouterState state) =>
            FestivalDetailScreen(
          festivalId: state.pathParameters['festivalId']!,
        ),
      ),

      // -- Rankings (no static variants) -----------------------------------
      GoRoute(
        path: '/rankings/:boardId',
        builder: (BuildContext context, GoRouterState state) =>
            RankingBoardDetailScreen(
          boardId: state.pathParameters['boardId']!,
          year: int.tryParse(state.uri.queryParameters['year'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/rankings/:boardId/entries/:entryId',
        builder: (BuildContext context, GoRouterState state) =>
            RankingEntryDetailScreen(
          boardId: state.pathParameters['boardId']!,
          entryId: state.pathParameters['entryId']!,
          year: int.tryParse(state.uri.queryParameters['year'] ?? ''),
        ),
      ),

      // -- Genres (no static variants) -------------------------------------
      GoRoute(
        path: '/genres/:genreId',
        builder: (BuildContext context, GoRouterState state) =>
            GenreDetailScreen(
          genreId: state.pathParameters['genreId']!,
        ),
      ),

      // -- Search ----------------------------------------------------------
      GoRoute(
        path: '/search',
        builder: (BuildContext context, GoRouterState state) {
          final query = state.uri.queryParameters['q'] ?? '';
          return SearchResultsScreen(initialQuery: query);
        },
      ),
    ];
