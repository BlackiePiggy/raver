import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_design_system/raver_design_system.dart';

import '../../data/events_repository.dart';

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

enum EventStatusFilter {
  all,
  ongoing,
  upcoming,
  ended;

  String get key => switch (this) {
        EventStatusFilter.all => '',
        EventStatusFilter.ongoing => 'ongoing',
        EventStatusFilter.upcoming => 'upcoming',
        EventStatusFilter.ended => 'ended',
      };

  String get label => switch (this) {
        EventStatusFilter.all => 'All',
        EventStatusFilter.ongoing => 'Ongoing',
        EventStatusFilter.upcoming => 'Upcoming',
        EventStatusFilter.ended => 'Ended',
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
  final Set<String> _favoriteMutations = <String>{};
  bool isFavoriteUpdating(String eventId) =>
      _favoriteMutations.contains(eventId);

  List<EventTypeFilter> _eventTypeFilters = const [];
  List<EventTypeFilter> get eventTypeFilters =>
      List.unmodifiable(_eventTypeFilters);
  EventTypeFilter get eventTypeFilter => _eventTypeFilters.length == 1
      ? _eventTypeFilters.first
      : EventTypeFilter.all;

  EventStatusFilter _statusFilter = EventStatusFilter.all;
  EventStatusFilter get statusFilter => _statusFilter;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _advancedSearchQuery = '';
  String get advancedSearchQuery => _advancedSearchQuery;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  String? get _effectiveSearch {
    final combined = [_searchQuery, _advancedSearchQuery]
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim();
    return combined.isEmpty ? null : combined;
  }

  String? get _effectiveEventType {
    final keys = _eventTypeFilters
        .where((filter) => filter != EventTypeFilter.all)
        .map((filter) => filter.key)
        .where((key) => key.isNotEmpty)
        .toList(growable: false);
    return keys.isEmpty ? null : keys.join(',');
  }

  String? get _effectiveStatus =>
      _statusFilter == EventStatusFilter.all ? null : _statusFilter.key;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      final page = await _repository.fetchEvents(
        page: 1,
        search: _effectiveSearch,
        eventType: _effectiveEventType,
        status: _effectiveStatus,
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
      _phase = LoadPhase.fromError(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    _isRefreshing = true;
    notifyListeners();

    try {
      final page = await _repository.fetchEvents(
        page: 1,
        search: _effectiveSearch,
        eventType: _effectiveEventType,
        status: _effectiveStatus,
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
        _phase = LoadPhase.fromError(e);
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
        search: _effectiveSearch,
        eventType: _effectiveEventType,
        status: _effectiveStatus,
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

  Future<void> setEventTypeFilter(EventTypeFilter filter) async {
    final nextFilters =
        filter == EventTypeFilter.all ? const <EventTypeFilter>[] : [filter];
    if (listEquals(_eventTypeFilters, nextFilters)) return;
    _eventTypeFilters = nextFilters;
    await load();
  }

  Future<void> setStatusFilter(EventStatusFilter filter) async {
    if (_statusFilter == filter) return;
    _statusFilter = filter;
    await load();
  }

  Future<void> setSearchQuery(String query) async {
    final normalized = query.trim();
    if (_searchQuery == normalized) return;
    _searchQuery = normalized;
    await load();
  }

  Future<void> applyAdvancedFilters({
    List<EventTypeFilter> eventTypes = const [],
    EventStatusFilter status = EventStatusFilter.all,
    String? city,
    String? brand,
  }) async {
    final nextTypes = eventTypes
        .where((filter) => filter != EventTypeFilter.all)
        .toList(growable: false);
    final nextAdvancedSearch = [
      city?.trim() ?? '',
      brand?.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ');

    if (listEquals(_eventTypeFilters, nextTypes) &&
        _statusFilter == status &&
        _advancedSearchQuery == nextAdvancedSearch) {
      return;
    }

    _eventTypeFilters = nextTypes;
    _statusFilter = status;
    _advancedSearchQuery = nextAdvancedSearch;
    await load();
  }

  Future<void> toggleFavorite(String eventId) async {
    if (_favoriteMutations.contains(eventId)) return;
    final index = _events.indexWhere((event) => event.id == eventId);
    if (index < 0) return;

    final original = _events[index];
    final wasFavorited = original.isFavorited == true;
    _favoriteMutations.add(eventId);
    _events[index] = _eventWithFavoriteState(
      original,
      isFavorited: !wasFavorited,
    );
    _phase = LoadPhase.success(_events);
    notifyListeners();

    try {
      final result = await _repository.toggleFavorite(
        eventId: eventId,
        currentlyFavorited: wasFavorited,
      );
      final latestIndex = _events.indexWhere((event) => event.id == eventId);
      if (latestIndex >= 0) {
        _events[latestIndex] = _eventWithFavoriteState(
          original,
          isFavorited: result,
        );
        _phase = LoadPhase.success(_events);
      }
    } catch (_) {
      final latestIndex = _events.indexWhere((event) => event.id == eventId);
      if (latestIndex >= 0) {
        _events[latestIndex] = original;
        _phase = LoadPhase.success(_events);
      }
    }

    _favoriteMutations.remove(eventId);
    notifyListeners();
  }

  WebEvent _eventWithFavoriteState(
    WebEvent event, {
    required bool isFavorited,
  }) {
    final current = event.isFavorited == true;
    final delta = current == isFavorited
        ? 0
        : isFavorited
            ? 1
            : -1;
    return event.copyWith(
      isFavorited: isFavorited,
      favoriteCount: (event.favoriteCount + delta).clamp(0, 1 << 31),
    );
  }
}
