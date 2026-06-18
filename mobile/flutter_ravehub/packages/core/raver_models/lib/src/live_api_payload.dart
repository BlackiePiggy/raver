import 'pagination.dart';

/// Helpers for the live BFF envelope shapes used across the Flutter app.
///
/// The backend commonly wraps objects and lists in `data`, `payload`, `result`,
/// or feature-specific keys. Keeping that tolerance here avoids each feature API
/// growing its own slightly different parser.
class LiveApiPayload {
  LiveApiPayload._();

  static const List<String> defaultObjectKeys = <String>[
    'data',
    'payload',
    'post',
    'comment',
    'genre',
    'ratingEvent',
    'ratingUnit',
    'squad',
    'profile',
    'checkin',
    'overview',
    'article',
    'dj',
    'set',
    'event',
    'label',
    'ranking',
    'board',
    'festival',
    'organizer',
    'preference',
    'submission',
    'shareLink',
    'upload',
    'item',
    'result',
    'object',
    'record',
  ];

  static const List<String> defaultItemKeys = <String>[
    'items',
    'list',
    'data',
    'posts',
    'comments',
    'results',
    'records',
    'squads',
    'events',
    'units',
  ];

  static Map<String, dynamic> object(
    Object? payload, {
    Iterable<String> objectKeys = defaultObjectKeys,
  }) {
    if (payload is Map<String, dynamic>) {
      for (final key in objectKeys) {
        final value = payload[key];
        if (value is Map<String, dynamic>) {
          return object(value, objectKeys: objectKeys);
        }
      }
      return payload;
    }
    return const <String, dynamic>{};
  }

  static List<dynamic> items(
    Object? payload, {
    Iterable<String> itemKeys = defaultItemKeys,
  }) {
    if (payload is List<dynamic>) return payload;
    if (payload is Map<String, dynamic>) {
      final keys = itemKeys.toList(growable: false);
      for (final key in itemKeys) {
        final value = payload[key];
        if (value is List<dynamic>) return value;
        if (value is Map<String, dynamic>) {
          final nested = items(value, itemKeys: itemKeys);
          if (nested.isNotEmpty) return nested;
        }
      }
      for (final key in defaultObjectKeys) {
        if (keys.contains(key)) continue;
        final value = payload[key];
        if (value is Map<String, dynamic>) {
          final nested = items(value, itemKeys: itemKeys);
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    return const <dynamic>[];
  }

  static BFFPagination? pagination(Object? payload) {
    if (payload is! Map<String, dynamic>) return null;
    final direct = payload['pagination'];
    if (direct is Map<String, dynamic>) return BFFPagination.fromJson(direct);

    for (final key in const ['data', 'payload', 'result', 'meta']) {
      final value = payload[key];
      if (value is Map<String, dynamic>) {
        final nested = pagination(value);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  static BFFListPage<T> listPage<T>(
    Object? payload,
    T Function(Map<String, dynamic> json) fromJson, {
    Iterable<String> itemKeys = defaultItemKeys,
  }) {
    return BFFListPage<T>(
      items: items(payload, itemKeys: itemKeys)
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList(),
      pagination: pagination(payload),
    );
  }

  static String? cursor(Object? payload) {
    final objectPayload = object(payload);
    final root = payload is Map<String, dynamic> ? payload : objectPayload;
    for (final source in [objectPayload, root]) {
      for (final key in const [
        'nextCursor',
        'next_cursor',
        'cursor',
        'next',
      ]) {
        final value = source[key];
        if (value != null) return value.toString();
      }
    }
    return null;
  }
}
