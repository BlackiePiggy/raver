import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:ravehub/router/deep_link_handler.dart';

class PushRouter {
  static void handleMessage(RemoteMessage message, GoRouter router) {
    final path = resolvePathFromData(message.data);
    if (path == null) return;
    router.push(path);
  }

  static String? resolvePathFromData(Map<String, dynamic> data) {
    final directPath = _directPath(data);
    if (directPath != null) return directPath;

    final type = _stringValue(data, const [
      'type',
      'targetType',
      'target_type',
      'entityType',
      'entity_type',
      'category',
    ]);
    final id = _stringValue(data, const [
      'id',
      'targetId',
      'target_id',
      'entityId',
      'entity_id',
      'resourceId',
      'resource_id',
    ]);

    if (type == null) return null;
    final normalized = _normalizeType(type);

    switch (normalized) {
      case 'inbox':
      case 'notification':
      case 'notifications':
        return '/inbox';
      case 'community':
      case 'community_alert':
        return '/inbox/alerts/community';
      case 'content_review':
      case 'content_reviews':
        return id == null ? '/inbox/content-reviews' : '/profile/publishes/$id';
      case 'checkin':
      case 'my_checkins':
        return '/profile/checkins';
      case 'followed_event':
      case 'followed_events':
        return '/inbox/followed-events';
      case 'followed_dj':
      case 'followed_djs':
        return '/inbox/followed-djs';
      case 'followed_brand':
      case 'followed_brands':
        return '/inbox/followed-brands';
    }

    if (id == null || id.isEmpty) return null;

    switch (normalized) {
      case 'event':
        return '/events/$id';
      case 'dj':
        return '/djs/$id';
      case 'set':
      case 'dj_set':
        return '/sets/$id';
      case 'post':
        return '/circle/post/$id';
      case 'squad':
        return '/circle/squads/$id';
      case 'news':
        return '/news/$id';
      case 'label':
      case 'brand':
        return '/labels/$id';
      case 'festival':
      case 'organizer':
        return '/festivals/$id';
      case 'ranking':
      case 'ranking_board':
        return '/rankings/$id';
      case 'rating':
      case 'rating_event':
        return '/circle/ratings/$id';
      case 'rating_unit':
        final parentId = _stringValue(data, const [
          'ratingId',
          'rating_id',
          'ratingEventId',
          'rating_event_id',
          'parentId',
          'parent_id',
        ]);
        return parentId == null
            ? '/circle/ratings'
            : '/circle/ratings/$parentId/units/$id';
      case 'circle_id':
        return '/circle/id/$id';
      case 'user':
      case 'profile':
        return '/users/$id';
      case 'submission':
      case 'content_submission':
        return '/profile/publishes/$id';
      default:
        return '/inbox';
    }
  }

  static String? _directPath(Map<String, dynamic> data) {
    final route = _stringValue(data, const [
      'route',
      'path',
      'deeplink',
      'deepLink',
      'deep_link',
      'link',
      'url',
      'appLink',
      'app_link',
    ]);
    if (route == null || route.isEmpty) return null;
    if (route.startsWith('/')) return route;
    final uri = Uri.tryParse(route);
    if (uri == null) return null;
    return DeepLinkHandler.toAppPath(uri);
  }

  static String? _stringValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }
    return null;
  }

  static String _normalizeType(String type) {
    return type.trim().toLowerCase().replaceAll('-', '_');
  }
}
