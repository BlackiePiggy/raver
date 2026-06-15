import 'package:raver_models/raver_models.dart';

import 'notification_api.dart';

/// Repository layer wrapping [NotificationApiService] with sensible defaults.
class NotificationRepository {
  NotificationRepository(this._api);

  final NotificationApiService _api;

  // ---------------------------------------------------------------------------
  // Community alerts (inbox)
  // ---------------------------------------------------------------------------

  Future<BFFListPage<AppNotification>> fetchInbox({
    required int page,
    int limit = 20,
  }) {
    return _api.fetchInbox(page: page, limit: limit);
  }

  // ---------------------------------------------------------------------------
  // Followed entities
  // ---------------------------------------------------------------------------

  Future<BFFListPage<FollowedEventNotificationItem>> fetchFollowedEvents({
    required int page,
    int limit = 20,
  }) {
    return _api.fetchFollowedEvents(page: page, limit: limit);
  }

  Future<BFFListPage<FollowedDJNotificationItem>> fetchFollowedDJs({
    required int page,
    int limit = 20,
  }) {
    return _api.fetchFollowedDJs(page: page, limit: limit);
  }

  Future<BFFListPage<FollowedBrandNotificationItem>> fetchFollowedBrands({
    required int page,
    int limit = 20,
  }) {
    return _api.fetchFollowedBrands(page: page, limit: limit);
  }

  // ---------------------------------------------------------------------------
  // Content reviews
  // ---------------------------------------------------------------------------

  Future<BFFListPage<ContentReviewNotificationItem>> fetchContentReviews({
    required int page,
    int limit = 20,
  }) {
    return _api.fetchContentReviews(page: page, limit: limit);
  }

  // ---------------------------------------------------------------------------
  // Unread counts
  // ---------------------------------------------------------------------------

  Future<NotificationUnreadCount> fetchUnreadCount() {
    return _api.fetchUnreadCount();
  }

  // ---------------------------------------------------------------------------
  // Mark as read
  // ---------------------------------------------------------------------------

  Future<void> markAsRead({
    required String category,
    required List<String> ids,
  }) {
    return _api.markAsRead(category: category, ids: ids);
  }
}
