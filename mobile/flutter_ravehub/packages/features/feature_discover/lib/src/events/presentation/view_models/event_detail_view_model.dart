import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_design_system/raver_design_system.dart';

import '../../data/event_discussion_models.dart';
import '../../data/event_manual_cache_store.dart';
import '../../data/events_repository.dart';

class EventDetailViewModel extends ChangeNotifier {
  EventDetailViewModel({
    required String eventId,
    required EventsRepository repository,
    EventManualCacheStore? manualCacheStore,
  })  : _eventId = eventId,
        _repository = repository,
        _manualCacheStore = manualCacheStore ?? EventManualCacheStore();

  final String _eventId;
  final EventsRepository _repository;
  final EventManualCacheStore _manualCacheStore;

  LoadPhase<WebEvent> _phase = const LoadPhase.loading();
  LoadPhase<WebEvent> get phase => _phase;

  WebEvent? _event;
  WebEvent? get event => _event;

  DateTime? _manualCachedAt;
  DateTime? get manualCachedAt => _manualCachedAt;

  bool _isShowingCachedEvent = false;
  bool get isShowingCachedEvent => _isShowingCachedEvent;

  List<WebEventLineupArtist> _lineup = [];
  List<WebEventLineupArtist> get lineup => _lineup;

  List<WebEventLineupSlot> _timetable = [];
  List<WebEventLineupSlot> get timetable => _timetable;

  List<Post> _relatedPosts = [];
  List<Post> get relatedPosts => List.unmodifiable(_relatedPosts);

  List<NewsArticle> _relatedNews = [];
  List<NewsArticle> get relatedNews => List.unmodifiable(_relatedNews);

  List<WebDJSet> _relatedSets = [];
  List<WebDJSet> get relatedSets => List.unmodifiable(_relatedSets);

  List<WebRatingEvent> _relatedRatingEvents = [];
  List<WebRatingEvent> get relatedRatingEvents =>
      List.unmodifiable(_relatedRatingEvents);

  List<WebCheckin> _relatedCheckins = [];
  List<WebCheckin> get relatedCheckins => List.unmodifiable(_relatedCheckins);

  bool _isFavorited = false;
  bool get isFavorited => _isFavorited;

  bool _isTogglingFavorite = false;
  bool get isTogglingFavorite => _isTogglingFavorite;

  bool _isCheckingIn = false;
  bool get isCheckingIn => _isCheckingIn;

  String? _myCheckinAt;
  String? get myCheckinAt => _myCheckinAt;
  bool get hasCheckedIn => _myCheckinAt != null;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      final event = await _repository.fetchEvent(id: _eventId);
      _event = event;
      _isFavorited = event.isFavorited ?? false;
      _isShowingCachedEvent = false;
      _phase = LoadPhase.success(event);
      notifyListeners();

      final cached = await _manualCacheStore.load(eventId: _eventId);
      _manualCachedAt = cached?.cachedAt;
      notifyListeners();

      await _loadSecondaryData();
    } catch (e) {
      final cached = await _manualCacheStore.load(eventId: _eventId);
      if (cached != null) {
        _event = cached.event;
        _isFavorited = cached.event.isFavorited ?? false;
        _manualCachedAt = cached.cachedAt;
        _isShowingCachedEvent = true;
        _lineup = cached.event.lineupArtists ?? const [];
        _timetable = cached.event.lineupSlots ?? const [];
        _phase = LoadPhase.success(cached.event);
        notifyListeners();
        return;
      }
      _phase = LoadPhase.fromError(e);
      notifyListeners();
    }
  }

  Future<DateTime?> cacheCurrentEvent() async {
    final event = _event;
    if (event == null) return null;
    final snapshot = await _manualCacheStore.save(event: event);
    _manualCachedAt = snapshot.cachedAt;
    notifyListeners();
    return snapshot.cachedAt;
  }

  Future<void> _loadSecondaryData() async {
    final results = await Future.wait<Object?>([
      _repository
          .fetchEventLineup(eventId: _eventId)
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _repository
          .fetchEventTimetable(eventId: _eventId)
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _repository
          .fetchCheckins(eventId: _eventId)
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _repository
          .fetchEventRelatedCheckins(eventId: _eventId, page: 1, limit: 20)
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _repository
          .fetchEventPosts(eventId: _eventId, limit: 20, mode: 'latest')
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _repository
          .fetchEventNews(eventId: _eventId, limit: 20)
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _repository
          .fetchEventSets(
            eventId: _eventId,
            eventName: _event?.name ?? '',
            limit: 200,
          )
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _repository
          .fetchEventRatingEvents(eventId: _eventId, page: 1, limit: 20)
          .then<Object?>((value) => value)
          .catchError((_) => null),
    ]);

    final lineup = results[0];
    if (lineup is List<WebEventLineupArtist>) {
      _lineup = lineup;
    }

    final timetable = results[1];
    if (timetable is List<WebEventLineupSlot>) {
      _timetable = timetable;
    }

    final checkins = results[2];
    if (checkins is EventCheckinList) {
      _myCheckinAt = checkins.myCheckinAt;
      final event = _event;
      if (event != null && checkins.totalCount > 0) {
        _event = event.copyWith(checkinCount: checkins.totalCount);
        _phase = LoadPhase.success(_event!);
      }
    }

    final relatedCheckins = results[3];
    if (relatedCheckins is BFFListPage<WebCheckin>) {
      _relatedCheckins = relatedCheckins.items;
    }

    final posts = results[4];
    if (posts is FeedPage) {
      _relatedPosts = posts.posts;
    }

    final news = results[5];
    if (news is NewsPage) {
      _relatedNews = news.articles;
    }

    final sets = results[6];
    if (sets is List<WebDJSet>) {
      _relatedSets = sets;
    }

    final ratings = results[7];
    if (ratings is List<WebRatingEvent>) {
      _relatedRatingEvents = ratings;
    }

    notifyListeners();
  }

  Future<void> toggleFavorite() async {
    if (_isTogglingFavorite) return;
    final original = _event;
    final wasFavorited = _isFavorited;

    _isTogglingFavorite = true;
    _errorMessage = null;
    _isFavorited = !wasFavorited;
    if (original != null) {
      _event = _eventWithFavoriteState(original, isFavorited: _isFavorited);
      _phase = LoadPhase.success(_event!);
    }
    notifyListeners();

    try {
      final result = await _repository.toggleFavorite(
        eventId: _eventId,
        currentlyFavorited: wasFavorited,
      );
      _isFavorited = result;
      if (original != null) {
        _event = _eventWithFavoriteState(original, isFavorited: result);
        _phase = LoadPhase.success(_event!);
      }
    } catch (e) {
      _isFavorited = wasFavorited;
      if (original != null) {
        _event = original;
        _phase = LoadPhase.success(original);
      }
      _errorMessage = e.toString();
    }
    _isTogglingFavorite = false;
    notifyListeners();
  }

  Future<void> checkin() async {
    if (_isCheckingIn || hasCheckedIn) return;
    final original = _event;
    _isCheckingIn = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.checkin(eventId: _eventId);
      _myCheckinAt = result.checkedInAt.isNotEmpty
          ? result.checkedInAt
          : DateTime.now().toUtc().toIso8601String();
      if (original != null) {
        _event = original.copyWith(checkinCount: original.checkinCount + 1);
        _phase = LoadPhase.success(_event!);
      }
      _relatedCheckins = [
        WebCheckin(
          id: result.checkinId.isNotEmpty ? result.checkinId : _eventId,
          userId: '',
          eventId: _eventId,
          eventName: original?.name ?? '',
          eventCoverUrl: original?.coverImageUrl ?? '',
          djId: '',
          djName: '',
          djAvatarUrl: '',
          type: 'event',
          note: '',
          rating: 0,
          attendedAt: _myCheckinAt!,
          createdAt: _myCheckinAt!,
        ),
        ..._relatedCheckins,
      ];
    } catch (e) {
      _event = original;
      if (original != null) {
        _phase = LoadPhase.success(original);
      }
      _errorMessage = e.toString();
    }

    _isCheckingIn = false;
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
