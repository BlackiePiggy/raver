import 'package:raver_models/raver_models.dart';

String? routeForSearchResult(GlobalSearchItem item) {
  final deeplink = item.deeplink?.trim();
  if (deeplink != null && deeplink.startsWith('/')) return deeplink;

  return switch (item.type) {
    GlobalSearchItemType.event => '/events/${item.entityId}',
    GlobalSearchItemType.dj => '/djs/${item.entityId}',
    GlobalSearchItemType.set => '/sets/${item.entityId}',
    GlobalSearchItemType.news => '/news/${item.entityId}',
    GlobalSearchItemType.label => '/labels/${item.entityId}',
    GlobalSearchItemType.festival => '/festivals/${item.entityId}',
    GlobalSearchItemType.rankingBoard => '/rankings/${item.entityId}',
    GlobalSearchItemType.rankingEntry => '/rankings/${item.entityId}',
    GlobalSearchItemType.ratingEvent => '/circle/ratings/${item.entityId}',
    GlobalSearchItemType.ratingUnit => null,
    GlobalSearchItemType.post => '/circle/post/${item.entityId}',
    GlobalSearchItemType.genre => '/genres/${item.entityId}',
    GlobalSearchItemType.user => '/users/${item.entityId}',
    GlobalSearchItemType.squad => '/circle/squads/${item.entityId}',
  };
}
