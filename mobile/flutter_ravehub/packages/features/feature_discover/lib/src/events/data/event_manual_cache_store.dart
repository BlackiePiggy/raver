import 'dart:convert';

import 'package:raver_models/raver_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EventManualCacheSnapshot {
  const EventManualCacheSnapshot({
    required this.event,
    required this.cachedAt,
  });

  final WebEvent event;
  final DateTime cachedAt;
}

class EventManualCacheStore {
  static const _keyPrefix = 'raver_event_manual_cache_';

  Future<EventManualCacheSnapshot?> load({required String eventId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(eventId));
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final eventJson = decoded['event'];
      final cachedAtRaw = decoded['cachedAt'];
      if (eventJson is! Map<String, dynamic> || cachedAtRaw is! String) {
        return null;
      }

      final cachedAt = DateTime.tryParse(cachedAtRaw);
      if (cachedAt == null) return null;

      return EventManualCacheSnapshot(
        event: WebEvent.fromJson(eventJson),
        cachedAt: cachedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<EventManualCacheSnapshot> save({required WebEvent event}) async {
    final cachedAt = DateTime.now().toUtc();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(event.id),
      jsonEncode({
        'cachedAt': cachedAt.toIso8601String(),
        'event': event.toJson(),
      }),
    );
    return EventManualCacheSnapshot(event: event, cachedAt: cachedAt);
  }

  Future<void> clear({required String eventId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(eventId));
  }

  static String _key(String eventId) => '$_keyPrefix$eventId';
}
