import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_design_system/raver_design_system.dart';

import '../data/events_repository.dart';

enum EventTypeFilter {
  all,
  festival,
  barEvent,
  outdoorEvent,
  clubParty,
  liveshow,
  warehouse,
  cruise,
  other;

  String get key => switch (this) {
        EventTypeFilter.all => '',
        EventTypeFilter.festival => 'festival',
        EventTypeFilter.barEvent => 'bar_event',
        EventTypeFilter.outdoorEvent => 'outdoor_event',
        EventTypeFilter.clubParty => 'club_party',
        EventTypeFilter.liveshow => 'liveshow',
        EventTypeFilter.warehouse => 'warehouse',
        EventTypeFilter.cruise => 'cruise',
        EventTypeFilter.other => 'other',
      };

  String get label => switch (this) {
        EventTypeFilter.all => 'All',
        EventTypeFilter.festival => 'Festival',
        EventTypeFilter.barEvent => 'Bar',
        EventTypeFilter.outdoorEvent => 'Outdoor',
        EventTypeFilter.clubParty => 'Club',
        EventTypeFilter.liveshow => 'Live Show',
        EventTypeFilter.warehouse => 'Warehouse',
        EventTypeFilter.cruise => 'Cruise',
        EventTypeFilter.other => 'Other',
      };
}

class EventsListViewModel extends ChangeNotifier {
  EventsListViewModel({required EventsRepository repository})
      : _repository = repository;

  final EventsRepository _repository;

  LoadPhase<List<WebEvent>> _phase = const LoadPhase.loading();
  LoadPhase<List<WebEvent>> get phase => _phase;

  final List<WebEvent> _events = [];
  List<WebEvent> get events => List.unmodifiable(_events);

  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  bool get canLoadMore => _currentPage < _totalPages;

  EventTypeFilter _eventTypeFilter = EventTypeFilter.all;
  EventTypeFilter get eventTypeFilter => _eventTypeFilter;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      final page = await _repository.fetchEvents(
        page: 1,
        eventType:
            _eventTypeFilter == EventTypeFilter.all ? null : _eventTypeFilter.key,
      );
      _events
        ..clear()
        ..addAll(page.items);
      _currentPage = 1;
      _totalPages = page.pagination?.totalPages ?? 1;
      _phase = _events.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_events);
    } catch (e) {
      _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    _isRefreshing = true;
    notifyListeners();

    try {
      final page = await _repository.fetchEvents(
        page: 1,
        eventType:
            _eventTypeFilter == EventTypeFilter.all ? null : _eventTypeFilter.key,
      );
      _events
        ..clear()
        ..addAll(page.items);
      _currentPage = 1;
      _totalPages = page.pagination?.totalPages ?? 1;
      _phase = _events.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_events);
    } catch (e) {
      if (_events.isEmpty) {
        _phase = LoadPhase.failure(e);
      }
    }
    _isRefreshing = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !canLoadMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final page = await _repository.fetchEvents(
        page: nextPage,
        eventType:
            _eventTypeFilter == EventTypeFilter.all ? null : _eventTypeFilter.key,
      );
      _events.addAll(page.items);
      _currentPage = nextPage;
      _totalPages = page.pagination?.totalPages ?? _totalPages;
      _phase = LoadPhase.success(_events);
    } catch (_) {
      // Silently fail on pagination; user can scroll again to retry.
    }
    _isLoadingMore = false;
    notifyListeners();
  }

  void setEventTypeFilter(EventTypeFilter filter) {
    if (_eventTypeFilter == filter) return;
    _eventTypeFilter = filter;
    load();
  }
}
