import 'package:feature_discover/src/search/presentation/search_result_route_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_models/raver_models.dart';

void main() {
  group('routeForSearchResult', () {
    test('prefers live internal deeplink when provided', () {
      expect(
        routeForSearchResult(
          _item(GlobalSearchItemType.ratingUnit,
              deeplink: '/circle/ratings/r1/units/u1'),
        ),
        '/circle/ratings/r1/units/u1',
      );
    });

    test('ignores non-app deeplink and falls back to local route', () {
      expect(
        routeForSearchResult(
          _item(GlobalSearchItemType.event,
              deeplink: 'https://ravehub.top/events/e1'),
        ),
        '/events/entity-1',
      );
    });

    test('maps all routable search result types to Flutter routes', () {
      final cases = <GlobalSearchItemType, String?>{
        GlobalSearchItemType.event: '/events/entity-1',
        GlobalSearchItemType.news: '/news/entity-1',
        GlobalSearchItemType.dj: '/djs/entity-1',
        GlobalSearchItemType.set: '/sets/entity-1',
        GlobalSearchItemType.rankingBoard: '/rankings/entity-1',
        GlobalSearchItemType.rankingEntry: '/rankings/entity-1',
        GlobalSearchItemType.ratingEvent: '/circle/ratings/entity-1',
        GlobalSearchItemType.ratingUnit: null,
        GlobalSearchItemType.post: '/circle/post/entity-1',
        GlobalSearchItemType.label: '/labels/entity-1',
        GlobalSearchItemType.festival: '/festivals/entity-1',
        GlobalSearchItemType.genre: '/genres/entity-1',
        GlobalSearchItemType.user: '/users/entity-1',
        GlobalSearchItemType.squad: '/circle/squads/entity-1',
      };

      for (final entry in cases.entries) {
        expect(
          routeForSearchResult(_item(entry.key)),
          entry.value,
          reason: '${entry.key} route should match app route table',
        );
      }
    });
  });
}

GlobalSearchItem _item(GlobalSearchItemType type, {String? deeplink}) =>
    GlobalSearchItem(
      id: '${type.name}-1',
      type: type,
      entityId: 'entity-1',
      title: type.name,
      deeplink: deeplink,
    );
