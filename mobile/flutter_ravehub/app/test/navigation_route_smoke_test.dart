import 'package:feature_auth/feature_auth.dart';
import 'package:feature_circle/feature_circle.dart';
import 'package:feature_discover/feature_discover.dart';
import 'package:feature_inbox/feature_inbox.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ravehub/di/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('navigation route smoke', () {
    test('sample locations cover every registered route pattern', () {
      final patterns = _routePatterns();

      expect(_routeSamples.keys, containsAll(patterns));
      expect(
        _routeSamples.keys.where((pattern) => !patterns.contains(pattern)),
        isEmpty,
      );
    });

    test('all route samples match the real app router', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);

      for (final entry in _routeSamples.entries) {
        final match = router.configuration.findMatch(Uri.parse(entry.value));

        expect(
          match.isError,
          isFalse,
          reason: '${entry.key} should match ${entry.value}',
        );
        expect(
          match.matches,
          isNotEmpty,
          reason: '${entry.key} should produce at least one route match',
        );
      }
    });
  });
}

Set<String> _routePatterns() {
  final patterns = <String>{
    '/',
    '/s/:code',
    '/scan',
  };

  for (final route in [
    ...buildAuthRoutes(),
    ...buildDiscoverRoutes(),
    ...buildDiscoverDetailRoutes(),
    ...buildCircleRoutes(),
    ...buildCircleDetailRoutes(),
    ...buildInboxRoutes(),
    ...buildInboxDetailRoutes(),
    ...buildProfileRoutes(),
    ...buildProfileDetailRoutes(),
  ]) {
    _collectRoutePatterns(route, patterns);
  }

  return patterns;
}

void _collectRoutePatterns(RouteBase route, Set<String> patterns) {
  if (route is GoRoute) {
    patterns.add(route.path);
  }
  for (final child in route.routes) {
    _collectRoutePatterns(child, patterns);
  }
}

const _routeSamples = <String, String>{
  '/': '/',
  '/s/:code': '/s/share123',
  '/scan': '/scan',
  '/login': '/login',
  '/register': '/register?returnTo=%2Fprofile',
  '/verify-code': '/verify-code?type=sms&phone=13800138000&countryCode=%2B86',
  '/forgot-password': '/forgot-password',
  '/discover': '/discover',
  '/events/new': '/events/new',
  '/events/:eventId': '/events/event-1',
  '/events/:eventId/edit': '/events/event-1/edit',
  '/events/:eventId/route':
      '/events/event-1/route?venueName=RaveHub&lat=31.2304&lng=121.4737',
  '/events/:eventId/lineup/import': '/events/event-1/lineup/import',
  '/djs/import': '/djs/import',
  '/djs/new': '/djs/new',
  '/djs/:djId': '/djs/dj-1',
  '/djs/:djId/edit': '/djs/dj-1/edit',
  '/sets/new': '/sets/new',
  '/sets/:setId/tracklist/edit': '/sets/set-1/tracklist/edit',
  '/sets/:setId': '/sets/set-1',
  '/sets/:setId/edit': '/sets/set-1/edit',
  '/news/new': '/news/new',
  '/news/:newsId': '/news/news-1',
  '/news/:newsId/edit': '/news/news-1/edit',
  '/labels/:labelId': '/labels/label-1',
  '/festivals/new': '/festivals/new',
  '/festivals/:festivalId': '/festivals/festival-1',
  '/rankings/:boardId': '/rankings/board-1?year=2026',
  '/rankings/:boardId/entries/:entryId':
      '/rankings/board-1/entries/entry-1?year=2026',
  '/genres/:genreId': '/genres/genre-1',
  '/search': '/search?q=techno',
  '/circle': '/circle',
  '/circle/post/:postId': '/circle/post/post-1',
  '/circle/compose': '/circle/compose',
  '/circle/squads/:squadId': '/circle/squads/squad-1',
  '/circle/squads/:squadId/manage': '/circle/squads/squad-1/manage',
  '/circle/squads/:squadId/activities': '/circle/squads/squad-1/activities',
  '/circle/ids/:cardId': '/circle/ids/card-1',
  '/circle/id/:cardId': '/circle/id/card-1',
  '/circle/ratings/:ratingId': '/circle/ratings/rating-1',
  '/circle/ratings/:ratingId/units/:unitId':
      '/circle/ratings/rating-1/units/unit-1',
  '/inbox': '/inbox',
  '/inbox/alerts/:categoryId': '/inbox/alerts/system',
  '/inbox/followed-events': '/inbox/followed-events',
  '/inbox/followed-djs': '/inbox/followed-djs',
  '/inbox/followed-brands': '/inbox/followed-brands',
  '/inbox/content-reviews': '/inbox/content-reviews',
  '/inbox/changes/:entityType/:entityId': '/inbox/changes/event/event-1',
  '/settings/notifications': '/settings/notifications',
  '/profile': '/profile',
  '/users/:userId': '/users/user-1',
  '/profile/edit': '/profile/edit',
  '/profile/settings': '/profile/settings',
  '/profile/settings/language': '/profile/settings/language',
  '/profile/settings/appearance': '/profile/settings/appearance',
  '/profile/settings/account-security': '/profile/settings/account-security',
  '/profile/settings/devices': '/profile/settings/devices',
  '/profile/settings/cache': '/profile/settings/cache',
  '/profile/settings/permissions': '/profile/settings/permissions',
  '/profile/settings/about': '/profile/settings/about',
  '/profile/checkins': '/profile/checkins',
  '/profile/publishes': '/profile/publishes',
  '/profile/publishes/:submissionId': '/profile/publishes/submission-1',
  '/profile/contributions': '/profile/contributions',
  '/profile/quiz': '/profile/quiz',
  '/profile/personality': '/profile/personality',
  '/profile/follow-list/:listType': '/profile/follow-list/following',
  '/users/:userId/follow-list/:listType': '/users/user-1/follow-list/friends',
  '/profile/saves': '/profile/saves',
  '/profile/virtual-assets': '/profile/virtual-assets',
  '/profile/tools/qr-code/:userId': '/profile/tools/qr-code/user-1',
  '/profile/tools/route': '/profile/tools/route',
  '/profile/tools/widgets': '/profile/tools/widgets',
  '/profile/tools/cinematic-banner': '/profile/tools/cinematic-banner',
};
