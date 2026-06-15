import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchStore extends ChangeNotifier {
  RecentSearchStore({
    this.key = 'globalSearch.recentQueries.v1',
    this.maxCount = 10,
  });

  final String key;
  final int maxCount;

  List<String> _queries = [];
  List<String> get queries => List.unmodifiable(_queries);

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(key) ?? [];
    _queries = _normalize(saved);
    _initialized = true;
    notifyListeners();
  }

  Future<void> record(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    final next = _queries
        .where((q) => q.toLowerCase() != query.toLowerCase())
        .toList();
    next.insert(0, query);
    _queries = _normalize(next);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, _queries);
  }

  Future<void> clear() async {
    _queries = [];
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  List<String> _normalize(List<String> items) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;
      final lowerKey = trimmed.toLowerCase();
      if (seen.contains(lowerKey)) continue;
      seen.add(lowerKey);
      result.add(trimmed);
      if (result.length >= maxCount) break;
    }
    return result;
  }
}
