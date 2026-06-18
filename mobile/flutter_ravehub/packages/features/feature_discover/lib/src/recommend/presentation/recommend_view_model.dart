import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_design_system/raver_design_system.dart';

import '../../events/data/events_repository.dart';

class RecommendViewModel extends ChangeNotifier {
  RecommendViewModel({required EventsRepository repository})
      : _repository = repository;

  final EventsRepository _repository;

  LoadPhase<List<WebEvent>> _phase = const LoadPhase.loading();
  LoadPhase<List<WebEvent>> get phase => _phase;

  List<WebEvent> _events = [];
  List<WebEvent> get events => _events;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  String? _bannerMessage;
  String? get bannerMessage => _bannerMessage;

  int _currentPageIndex = 0;
  int get currentPageIndex => _currentPageIndex;

  bool _hasLoaded = false;

  static String? _cachedDateKey;
  static List<WebEvent>? _cachedEvents;

  Future<void> loadIfNeeded() async {
    if (_hasLoaded && _events.isNotEmpty) return;

    final todayKey = _todayKey();
    if (_cachedDateKey == todayKey &&
        _cachedEvents != null &&
        _cachedEvents!.isNotEmpty) {
      _events = _cachedEvents!;
      _phase = LoadPhase.success(_events);
      _hasLoaded = true;
      notifyListeners();
      return;
    }

    await _loadRecommendations();
  }

  Future<void> reload() async {
    _isRefreshing = true;
    notifyListeners();
    await _loadRecommendations();
    _isRefreshing = false;
    notifyListeners();
  }

  void setPageIndex(int index) {
    _currentPageIndex = index;
    notifyListeners();
  }

  Future<void> _loadRecommendations() async {
    final hadContent = _events.isNotEmpty;
    if (!hadContent) {
      _phase = const LoadPhase.loading();
      notifyListeners();
    }

    try {
      var recommended = await _repository.fetchRecommendedEvents(
        limit: 10,
        statuses: const ['ongoing', 'upcoming', 'ended'],
      );

      if (recommended.isEmpty) {
        recommended = await _loadFallback();
      }

      _events = recommended;
      _cacheRecommendations(recommended);
      _hasLoaded = true;
      _bannerMessage = null;
      _phase = _events.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_events);
    } catch (e) {
      try {
        final fallback = await _loadFallback();
        _events = fallback;
        _cacheRecommendations(fallback);
        _hasLoaded = true;
        _bannerMessage = null;
        _phase = _events.isEmpty
            ? const LoadPhase.empty()
            : LoadPhase.success(_events);
      } catch (e2) {
        if (hadContent) {
          _bannerMessage = e2.toString();
          _phase = LoadPhase.success(_events);
        } else {
          _phase = LoadPhase.failure(e2);
        }
      }
    }
    notifyListeners();
  }

  Future<List<WebEvent>> _loadFallback() async {
    final page = await _repository.fetchEvents(
      page: 1,
      limit: 10,
      status: 'upcoming',
    );
    final sorted = List<WebEvent>.from(page.items)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return sorted.take(10).toList();
  }

  void _cacheRecommendations(List<WebEvent> events) {
    if (events.isEmpty) return;
    _cachedDateKey = _todayKey();
    _cachedEvents = events;
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
