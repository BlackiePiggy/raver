import 'package:flutter/foundation.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

import '../../data/notification_repository.dart';

/// Manages unread counts, latest notification previews, and per-category lists
/// for the inbox home screen and sub-screens.
class InboxViewModel extends ChangeNotifier {
  InboxViewModel({required NotificationRepository repository})
      : _repository = repository;

  final NotificationRepository _repository;

  // ---------------------------------------------------------------------------
  // Unread counts
  // ---------------------------------------------------------------------------

  LoadPhase<NotificationUnreadCount> _unreadPhase = const LoadPhase.loading();
  LoadPhase<NotificationUnreadCount> get unreadPhase => _unreadPhase;

  NotificationUnreadCount? _unreadCount;
  NotificationUnreadCount? get unreadCount => _unreadCount;

  // ---------------------------------------------------------------------------
  // Community alerts (inbox)
  // ---------------------------------------------------------------------------

  LoadPhase<List<AppNotification>> _alertsPhase = const LoadPhase.loading();
  LoadPhase<List<AppNotification>> get alertsPhase => _alertsPhase;

  final List<AppNotification> _alerts = [];
  List<AppNotification> get alerts => List.unmodifiable(_alerts);

  int _alertsPage = 1;
  int _alertsTotalPages = 1;
  bool _isLoadingMoreAlerts = false;
  bool get isLoadingMoreAlerts => _isLoadingMoreAlerts;
  bool get canLoadMoreAlerts => _alertsPage < _alertsTotalPages;

  // ---------------------------------------------------------------------------
  // Followed events
  // ---------------------------------------------------------------------------

  LoadPhase<List<FollowedEventNotificationItem>> _followedEventsPhase =
      const LoadPhase.loading();
  LoadPhase<List<FollowedEventNotificationItem>> get followedEventsPhase =>
      _followedEventsPhase;

  final List<FollowedEventNotificationItem> _followedEvents = [];
  List<FollowedEventNotificationItem> get followedEvents =>
      List.unmodifiable(_followedEvents);

  int _followedEventsPage = 1;
  int _followedEventsTotalPages = 1;
  bool _isLoadingMoreFollowedEvents = false;
  bool get isLoadingMoreFollowedEvents => _isLoadingMoreFollowedEvents;
  bool get canLoadMoreFollowedEvents =>
      _followedEventsPage < _followedEventsTotalPages;

  // ---------------------------------------------------------------------------
  // Followed DJs
  // ---------------------------------------------------------------------------

  LoadPhase<List<FollowedDJNotificationItem>> _followedDJsPhase =
      const LoadPhase.loading();
  LoadPhase<List<FollowedDJNotificationItem>> get followedDJsPhase =>
      _followedDJsPhase;

  final List<FollowedDJNotificationItem> _followedDJs = [];
  List<FollowedDJNotificationItem> get followedDJs =>
      List.unmodifiable(_followedDJs);

  int _followedDJsPage = 1;
  int _followedDJsTotalPages = 1;
  bool _isLoadingMoreFollowedDJs = false;
  bool get isLoadingMoreFollowedDJs => _isLoadingMoreFollowedDJs;
  bool get canLoadMoreFollowedDJs =>
      _followedDJsPage < _followedDJsTotalPages;

  // ---------------------------------------------------------------------------
  // Followed brands
  // ---------------------------------------------------------------------------

  LoadPhase<List<FollowedBrandNotificationItem>> _followedBrandsPhase =
      const LoadPhase.loading();
  LoadPhase<List<FollowedBrandNotificationItem>> get followedBrandsPhase =>
      _followedBrandsPhase;

  final List<FollowedBrandNotificationItem> _followedBrands = [];
  List<FollowedBrandNotificationItem> get followedBrands =>
      List.unmodifiable(_followedBrands);

  int _followedBrandsPage = 1;
  int _followedBrandsTotalPages = 1;
  bool _isLoadingMoreFollowedBrands = false;
  bool get isLoadingMoreFollowedBrands => _isLoadingMoreFollowedBrands;
  bool get canLoadMoreFollowedBrands =>
      _followedBrandsPage < _followedBrandsTotalPages;

  // ---------------------------------------------------------------------------
  // Content reviews
  // ---------------------------------------------------------------------------

  LoadPhase<List<ContentReviewNotificationItem>> _contentReviewsPhase =
      const LoadPhase.loading();
  LoadPhase<List<ContentReviewNotificationItem>> get contentReviewsPhase =>
      _contentReviewsPhase;

  final List<ContentReviewNotificationItem> _contentReviews = [];
  List<ContentReviewNotificationItem> get contentReviews =>
      List.unmodifiable(_contentReviews);

  int _contentReviewsPage = 1;
  int _contentReviewsTotalPages = 1;
  bool _isLoadingMoreContentReviews = false;
  bool get isLoadingMoreContentReviews => _isLoadingMoreContentReviews;
  bool get canLoadMoreContentReviews =>
      _contentReviewsPage < _contentReviewsTotalPages;

  // =========================================================================
  // Load methods
  // =========================================================================

  /// Loads the unread counts for the home screen.
  Future<void> loadUnreadCounts() async {
    _unreadPhase = const LoadPhase.loading();
    notifyListeners();

    try {
      final counts = await _repository.fetchUnreadCount();
      _unreadCount = counts;
      _unreadPhase = LoadPhase.success(counts);
    } catch (e) {
      _unreadPhase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Alerts
  // ---------------------------------------------------------------------------

  Future<void> loadAlerts() async {
    _alertsPhase = const LoadPhase.loading();
    notifyListeners();

    try {
      final page = await _repository.fetchInbox(page: 1);
      _alerts
        ..clear()
        ..addAll(page.items);
      _alertsPage = 1;
      _alertsTotalPages = page.pagination?.totalPages ?? 1;
      _alertsPhase = _alerts.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_alerts);
    } catch (e) {
      _alertsPhase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> refreshAlerts() async {
    try {
      final page = await _repository.fetchInbox(page: 1);
      _alerts
        ..clear()
        ..addAll(page.items);
      _alertsPage = 1;
      _alertsTotalPages = page.pagination?.totalPages ?? 1;
      _alertsPhase = _alerts.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_alerts);
    } catch (e) {
      if (_alerts.isEmpty) _alertsPhase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> loadMoreAlerts() async {
    if (_isLoadingMoreAlerts || !canLoadMoreAlerts) return;
    _isLoadingMoreAlerts = true;
    notifyListeners();

    try {
      final nextPage = _alertsPage + 1;
      final page = await _repository.fetchInbox(page: nextPage);
      _alerts.addAll(page.items);
      _alertsPage = nextPage;
      _alertsTotalPages = page.pagination?.totalPages ?? _alertsTotalPages;
      _alertsPhase = LoadPhase.success(_alerts);
    } catch (_) {}
    _isLoadingMoreAlerts = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Followed events
  // ---------------------------------------------------------------------------

  Future<void> loadFollowedEvents() async {
    _followedEventsPhase = const LoadPhase.loading();
    notifyListeners();

    try {
      final page = await _repository.fetchFollowedEvents(page: 1);
      _followedEvents
        ..clear()
        ..addAll(page.items);
      _followedEventsPage = 1;
      _followedEventsTotalPages = page.pagination?.totalPages ?? 1;
      _followedEventsPhase = _followedEvents.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_followedEvents);
    } catch (e) {
      _followedEventsPhase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> refreshFollowedEvents() async {
    try {
      final page = await _repository.fetchFollowedEvents(page: 1);
      _followedEvents
        ..clear()
        ..addAll(page.items);
      _followedEventsPage = 1;
      _followedEventsTotalPages = page.pagination?.totalPages ?? 1;
      _followedEventsPhase = _followedEvents.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_followedEvents);
    } catch (e) {
      if (_followedEvents.isEmpty) {
        _followedEventsPhase = LoadPhase.failure(e);
      }
    }
    notifyListeners();
  }

  Future<void> loadMoreFollowedEvents() async {
    if (_isLoadingMoreFollowedEvents || !canLoadMoreFollowedEvents) return;
    _isLoadingMoreFollowedEvents = true;
    notifyListeners();

    try {
      final nextPage = _followedEventsPage + 1;
      final page = await _repository.fetchFollowedEvents(page: nextPage);
      _followedEvents.addAll(page.items);
      _followedEventsPage = nextPage;
      _followedEventsTotalPages =
          page.pagination?.totalPages ?? _followedEventsTotalPages;
      _followedEventsPhase = LoadPhase.success(_followedEvents);
    } catch (_) {}
    _isLoadingMoreFollowedEvents = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Followed DJs
  // ---------------------------------------------------------------------------

  Future<void> loadFollowedDJs() async {
    _followedDJsPhase = const LoadPhase.loading();
    notifyListeners();

    try {
      final page = await _repository.fetchFollowedDJs(page: 1);
      _followedDJs
        ..clear()
        ..addAll(page.items);
      _followedDJsPage = 1;
      _followedDJsTotalPages = page.pagination?.totalPages ?? 1;
      _followedDJsPhase = _followedDJs.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_followedDJs);
    } catch (e) {
      _followedDJsPhase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> refreshFollowedDJs() async {
    try {
      final page = await _repository.fetchFollowedDJs(page: 1);
      _followedDJs
        ..clear()
        ..addAll(page.items);
      _followedDJsPage = 1;
      _followedDJsTotalPages = page.pagination?.totalPages ?? 1;
      _followedDJsPhase = _followedDJs.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_followedDJs);
    } catch (e) {
      if (_followedDJs.isEmpty) _followedDJsPhase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> loadMoreFollowedDJs() async {
    if (_isLoadingMoreFollowedDJs || !canLoadMoreFollowedDJs) return;
    _isLoadingMoreFollowedDJs = true;
    notifyListeners();

    try {
      final nextPage = _followedDJsPage + 1;
      final page = await _repository.fetchFollowedDJs(page: nextPage);
      _followedDJs.addAll(page.items);
      _followedDJsPage = nextPage;
      _followedDJsTotalPages =
          page.pagination?.totalPages ?? _followedDJsTotalPages;
      _followedDJsPhase = LoadPhase.success(_followedDJs);
    } catch (_) {}
    _isLoadingMoreFollowedDJs = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Followed brands
  // ---------------------------------------------------------------------------

  Future<void> loadFollowedBrands() async {
    _followedBrandsPhase = const LoadPhase.loading();
    notifyListeners();

    try {
      final page = await _repository.fetchFollowedBrands(page: 1);
      _followedBrands
        ..clear()
        ..addAll(page.items);
      _followedBrandsPage = 1;
      _followedBrandsTotalPages = page.pagination?.totalPages ?? 1;
      _followedBrandsPhase = _followedBrands.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_followedBrands);
    } catch (e) {
      _followedBrandsPhase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> refreshFollowedBrands() async {
    try {
      final page = await _repository.fetchFollowedBrands(page: 1);
      _followedBrands
        ..clear()
        ..addAll(page.items);
      _followedBrandsPage = 1;
      _followedBrandsTotalPages = page.pagination?.totalPages ?? 1;
      _followedBrandsPhase = _followedBrands.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_followedBrands);
    } catch (e) {
      if (_followedBrands.isEmpty) {
        _followedBrandsPhase = LoadPhase.failure(e);
      }
    }
    notifyListeners();
  }

  Future<void> loadMoreFollowedBrands() async {
    if (_isLoadingMoreFollowedBrands || !canLoadMoreFollowedBrands) return;
    _isLoadingMoreFollowedBrands = true;
    notifyListeners();

    try {
      final nextPage = _followedBrandsPage + 1;
      final page = await _repository.fetchFollowedBrands(page: nextPage);
      _followedBrands.addAll(page.items);
      _followedBrandsPage = nextPage;
      _followedBrandsTotalPages =
          page.pagination?.totalPages ?? _followedBrandsTotalPages;
      _followedBrandsPhase = LoadPhase.success(_followedBrands);
    } catch (_) {}
    _isLoadingMoreFollowedBrands = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Content reviews
  // ---------------------------------------------------------------------------

  Future<void> loadContentReviews() async {
    _contentReviewsPhase = const LoadPhase.loading();
    notifyListeners();

    try {
      final page = await _repository.fetchContentReviews(page: 1);
      _contentReviews
        ..clear()
        ..addAll(page.items);
      _contentReviewsPage = 1;
      _contentReviewsTotalPages = page.pagination?.totalPages ?? 1;
      _contentReviewsPhase = _contentReviews.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_contentReviews);
    } catch (e) {
      _contentReviewsPhase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> refreshContentReviews() async {
    try {
      final page = await _repository.fetchContentReviews(page: 1);
      _contentReviews
        ..clear()
        ..addAll(page.items);
      _contentReviewsPage = 1;
      _contentReviewsTotalPages = page.pagination?.totalPages ?? 1;
      _contentReviewsPhase = _contentReviews.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_contentReviews);
    } catch (e) {
      if (_contentReviews.isEmpty) {
        _contentReviewsPhase = LoadPhase.failure(e);
      }
    }
    notifyListeners();
  }

  Future<void> loadMoreContentReviews() async {
    if (_isLoadingMoreContentReviews || !canLoadMoreContentReviews) return;
    _isLoadingMoreContentReviews = true;
    notifyListeners();

    try {
      final nextPage = _contentReviewsPage + 1;
      final page = await _repository.fetchContentReviews(page: nextPage);
      _contentReviews.addAll(page.items);
      _contentReviewsPage = nextPage;
      _contentReviewsTotalPages =
          page.pagination?.totalPages ?? _contentReviewsTotalPages;
      _contentReviewsPhase = LoadPhase.success(_contentReviews);
    } catch (_) {}
    _isLoadingMoreContentReviews = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Mark as read
  // ---------------------------------------------------------------------------

  Future<void> markAsRead({
    required String category,
    required List<String> ids,
  }) async {
    try {
      await _repository.markAsRead(category: category, ids: ids);
    } catch (_) {
      // Non-critical; silently ignore.
    }
  }
}
