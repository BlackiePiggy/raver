import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

/// API service for the notification center endpoints.
class NotificationApiService {
  NotificationApiService(this._dio);

  final Dio _dio;

  // ---------------------------------------------------------------------------
  // Community alerts (inbox)
  // ---------------------------------------------------------------------------

  /// GET /v1/notification-center/inbox
  Future<BFFListPage<AppNotification>> fetchInbox({
    required int page,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/notification-center/inbox',
      queryParameters: {'page': page, 'limit': limit},
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) => AppNotification.fromJson(json! as Map<String, dynamic>),
    );
  }

  // ---------------------------------------------------------------------------
  // Followed events
  // ---------------------------------------------------------------------------

  /// GET /v1/notification-center/followed-events/items
  Future<BFFListPage<FollowedEventNotificationItem>> fetchFollowedEvents({
    required int page,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/notification-center/followed-events/items',
      queryParameters: {'page': page, 'limit': limit},
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) =>
          FollowedEventNotificationItem.fromJson(json! as Map<String, dynamic>),
    );
  }

  // ---------------------------------------------------------------------------
  // Followed DJs
  // ---------------------------------------------------------------------------

  /// GET /v1/notification-center/followed-djs/items
  Future<BFFListPage<FollowedDJNotificationItem>> fetchFollowedDJs({
    required int page,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/notification-center/followed-djs/items',
      queryParameters: {'page': page, 'limit': limit},
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) =>
          FollowedDJNotificationItem.fromJson(json! as Map<String, dynamic>),
    );
  }

  // ---------------------------------------------------------------------------
  // Followed brands
  // ---------------------------------------------------------------------------

  /// GET /v1/notification-center/followed-brands/items
  Future<BFFListPage<FollowedBrandNotificationItem>> fetchFollowedBrands({
    required int page,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/notification-center/followed-brands/items',
      queryParameters: {'page': page, 'limit': limit},
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) =>
          FollowedBrandNotificationItem.fromJson(json! as Map<String, dynamic>),
    );
  }

  // ---------------------------------------------------------------------------
  // Content reviews
  // ---------------------------------------------------------------------------

  /// GET /v1/notification-center/content-reviews/items
  Future<BFFListPage<ContentReviewNotificationItem>> fetchContentReviews({
    required int page,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/notification-center/content-reviews/items',
      queryParameters: {'page': page, 'limit': limit},
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) =>
          ContentReviewNotificationItem.fromJson(json! as Map<String, dynamic>),
    );
  }

  // ---------------------------------------------------------------------------
  // Unread counts
  // ---------------------------------------------------------------------------

  /// GET /v1/notification-center/unread-count
  Future<NotificationUnreadCount> fetchUnreadCount() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/notification-center/unread-count',
    );
    return NotificationUnreadCount.fromJson(response.data!);
  }

  // ---------------------------------------------------------------------------
  // Mark as read
  // ---------------------------------------------------------------------------

  /// PUT /v1/notification-center/read
  Future<void> markAsRead({
    required String category,
    required List<String> ids,
  }) async {
    await _dio.put<void>(
      '/v1/notification-center/read',
      data: {'category': category, 'ids': ids},
    );
  }

  Future<void> markFollowedEventRead({required String itemId}) async {
    await _dio.post<void>(
      '/v1/notification-center/followed-events/read',
      data: {'itemId': itemId},
    );
  }

  Future<void> markFollowedDJRead({required String itemId}) async {
    await _dio.post<void>(
      '/v1/notification-center/followed-djs/read',
      data: {'itemId': itemId},
    );
  }

  Future<void> markFollowedBrandRead({required String itemId}) async {
    await _dio.post<void>(
      '/v1/notification-center/followed-brands/read',
      data: {'itemId': itemId},
    );
  }

  // ---------------------------------------------------------------------------
  // Push token registration
  // ---------------------------------------------------------------------------

  /// Registers or updates the device push token with the backend.
  ///
  /// [token] is the FCM (iOS/Android) or Harmony Push Kit token.
  /// [platform] is one of: "ios", "android", "harmony".
  Future<void> registerPushToken({
    required String token,
    required String platform,
  }) async {
    await _dio.post<void>(
      '/v1/notification-center/push-tokens',
      data: {'token': token, 'platform': platform},
    );
  }
}
