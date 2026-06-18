import 'dart:io';

import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_network/raver_network.dart';

import 'event_discussion_models.dart';

// ---------------------------------------------------------------------------
// LineupImportMatch — result of AI OCR lineup poster import
// ---------------------------------------------------------------------------

/// A single matched DJ returned by the lineup-poster OCR endpoint.
class LineupImportMatch {
  LineupImportMatch({
    required this.djName,
    this.djId,
    required this.confidence,
    this.avatarUrl,
  });

  /// The detected DJ name from the poster.
  final String djName;

  /// The matched DJ's ID in the database, or `null` if no match was found.
  final String? djId;

  /// Confidence score for the match, ranging from 0.0 to 1.0.
  final double confidence;

  /// Avatar URL for the matched DJ, if available.
  final String? avatarUrl;

  factory LineupImportMatch.fromJson(Map<String, dynamic> json) {
    final name = _firstString(
      json,
      const ['djName', 'dj_name', 'musician', 'artist', 'name', 'dj'],
    );
    return LineupImportMatch(
      djName: name ?? '',
      djId: _firstString(json, const ['djId', 'djID', 'dj_id']),
      confidence: _numberAsDouble(json['confidence']) ?? 1,
      avatarUrl: _firstString(
        json,
        const ['avatarUrl', 'avatarURL', 'avatar_url', 'imageUrl', 'imageURL'],
      ),
    );
  }
}

class EventsApiService {
  EventsApiService(this._dio);

  final Dio _dio;

  Future<BFFListPage<WebEvent>> fetchEvents({
    required int page,
    required int limit,
    String? search,
    String? eventType,
    String? status,
    String? wikiFestivalId,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
      if (eventType != null && eventType.isNotEmpty) 'eventType': eventType,
      if (status != null && status.isNotEmpty) 'status': status,
      if (wikiFestivalId != null) 'wikiFestivalId': wikiFestivalId,
    };

    final response = await _dio.get<dynamic>(
      '/v1/events',
      queryParameters: queryParameters,
    );
    final pageData = LiveApiPayload.listPage<WebEvent>(
      response.data,
      WebEvent.fromJson,
    );
    final pagination = response.extra[kPaginationExtraKey];
    if (pagination is Map<String, dynamic>) {
      return pageData.copyWith(pagination: BFFPagination.fromJson(pagination));
    }
    return pageData;
  }

  Future<List<WebEvent>> fetchRecommendedEvents({
    required int limit,
    List<String>? statuses,
  }) async {
    final queryParameters = <String, dynamic>{
      'limit': limit,
      if (statuses != null) 'statuses': statuses.join(','),
    };

    final response = await _dio.get<dynamic>(
      '/v1/events/recommendations',
      queryParameters: queryParameters,
    );
    return LiveApiPayload.items(response.data)
        .whereType<Map<String, dynamic>>()
        .map(WebEvent.fromJson)
        .toList();
  }

  Future<WebEvent> fetchEvent({required String id}) async {
    final response = await _dio.get<dynamic>('/v1/events/$id');
    return WebEvent.fromJson(LiveApiPayload.object(response.data));
  }

  Future<WebEvent> fetchEventSummary({required String id}) async {
    final response = await _dio.get<dynamic>(
      '/v1/events/$id/summary',
    );
    return WebEvent.fromJson(LiveApiPayload.object(response.data));
  }

  Future<List<WebEventLineupArtist>> fetchEventLineup({
    required String eventId,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/events/$eventId/lineup',
    );
    return LiveApiPayload.items(response.data)
        .whereType<Map<String, dynamic>>()
        .map(WebEventLineupArtist.fromJson)
        .toList();
  }

  Future<List<WebEventLineupSlot>> fetchEventTimetable({
    required String eventId,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/events/$eventId/timetable',
    );
    return LiveApiPayload.items(response.data)
        .whereType<Map<String, dynamic>>()
        .map(WebEventLineupSlot.fromJson)
        .toList();
  }

  Future<FeedPage> fetchEventPosts({
    required String eventId,
    int limit = 20,
    String mode = 'latest',
    String? cursor,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/feed',
      queryParameters: {
        'limit': limit,
        if (mode.trim().isNotEmpty) 'mode': mode.trim(),
        if (eventId.trim().isNotEmpty) 'eventId': eventId.trim(),
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      },
    );
    return FeedPage(
      posts: LiveApiPayload.items(
        response.data,
        itemKeys: const ['posts', 'items', 'list', 'data'],
      ).whereType<Map<String, dynamic>>().map(Post.fromJson).toList(),
      nextCursor: LiveApiPayload.cursor(response.data),
    );
  }

  Future<List<WebDJSet>> fetchEventSets({
    required String eventId,
    String eventName = '',
    int limit = 200,
  }) async {
    final trimmedEventId = eventId.trim();
    final trimmedEventName = eventName.trim();
    final response = await _dio.get<dynamic>(
      '/v1/dj-sets',
      queryParameters: {
        'page': 1,
        'limit': limit.clamp(1, 200),
        'sortBy': 'latest',
        if (trimmedEventId.isNotEmpty) 'eventId': trimmedEventId,
        if (trimmedEventName.isNotEmpty) 'eventName': trimmedEventName,
      },
    );
    return LiveApiPayload.items(response.data)
        .whereType<Map<String, dynamic>>()
        .map(WebDJSet.fromJson)
        .toList();
  }

  Future<List<WebRatingEvent>> fetchEventRatingEvents({
    required String eventId,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/events/$eventId/rating-events',
      queryParameters: {
        'page': page.clamp(1, 1 << 31),
        'limit': limit.clamp(1, 100),
      },
    );
    return LiveApiPayload.items(response.data)
        .whereType<Map<String, dynamic>>()
        .map(WebRatingEvent.fromJson)
        .toList();
  }

  Future<NewsPage> fetchEventNews({
    required String eventId,
    int limit = 20,
    String? cursor,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/news/bound',
      queryParameters: {
        'limit': limit.clamp(1, 100),
        if (eventId.trim().isNotEmpty) 'eventId': eventId.trim(),
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      },
    );
    return NewsPage(
      articles: LiveApiPayload.items(
        response.data,
        itemKeys: const ['articles', 'items', 'list', 'data'],
      ).whereType<Map<String, dynamic>>().map(NewsArticle.fromJson).toList(),
      nextCursor: LiveApiPayload.cursor(response.data),
    );
  }

  Future<EventFavoriteStatus> fetchFavoriteStatus({
    required String eventId,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/events/$eventId/favorite',
    );
    return EventFavoriteStatus.fromJson(LiveApiPayload.object(response.data));
  }

  Future<EventFavoriteStatus> favoriteEvent({required String eventId}) async {
    final response = await _dio.post<dynamic>(
      '/v1/events/$eventId/favorite',
    );
    return EventFavoriteStatus.fromJson(LiveApiPayload.object(response.data));
  }

  Future<void> unfavoriteEvent({required String eventId}) async {
    await _dio.delete<void>('/v1/events/$eventId/favorite');
  }

  Future<ShareLinkPayload> resolveShareLink({
    required WebEvent event,
    String channel = 'system_share',
  }) async {
    final canonicalUrl = 'https://ravehub.top/events/${event.id}';
    final response = await _dio.post<dynamic>(
      '/v1/share-links/resolve',
      data: {
        'targetType': 'event',
        'targetId': event.id,
        'channel': channel,
        'preferPermanent': true,
        'targetSeed': {
          'title': event.name,
          if (event.description.isNotEmpty) 'subtitle': event.description,
          if (event.coverImageUrl.isNotEmpty) 'imageUrl': event.coverImageUrl,
          'canonicalUrl': canonicalUrl,
          'deepLink': 'raver://events/${event.id}',
          'fallbackUrl': canonicalUrl,
          'previewType': 'event_card',
          'visibility': 'public',
        },
      },
    );
    return ShareLinkPayload.fromJson(LiveApiPayload.object(response.data));
  }

  Future<GlobalSearchResponse> searchGlobal({
    required String query,
    required String tab,
    required int limit,
    String locale = 'en',
  }) async {
    final keyword = query.trim();
    final response = await _dio.get<dynamic>(
      '/v1/search',
      queryParameters: {
        if (keyword.isNotEmpty) 'q': keyword,
        'tab': tab,
        'limit': limit.clamp(1, 80),
        'locale': locale,
      },
    );
    return GlobalSearchResponse.fromJson(LiveApiPayload.object(response.data));
  }

  // ---------------------------------------------------------------------------
  // Discussion
  // ---------------------------------------------------------------------------

  Future<EventDiscussionPage> fetchDiscussion({
    required String eventId,
    String? cursor,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/events/$eventId/discussion',
      queryParameters: {if (cursor != null) 'cursor': cursor},
    );
    return EventDiscussionPage.fromJson(LiveApiPayload.object(response.data));
  }

  Future<EventDiscussionComment> postComment({
    required String eventId,
    required String content,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/events/$eventId/discussion',
      data: {'content': content},
    );
    return EventDiscussionComment.fromJson(
      LiveApiPayload.object(response.data),
    );
  }

  // ---------------------------------------------------------------------------
  // Check-in
  // ---------------------------------------------------------------------------

  Future<EventCheckinResult> checkin({required String eventId}) async {
    final response = await _dio.post<dynamic>(
      '/v1/events/$eventId/checkin',
    );
    return EventCheckinResult.fromJson(LiveApiPayload.object(response.data));
  }

  Future<EventCheckinList> fetchCheckins({
    required String eventId,
    int limit = 10,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/events/$eventId/checkins',
      queryParameters: {'limit': limit},
    );
    return EventCheckinList.fromJson(LiveApiPayload.object(response.data));
  }

  Future<BFFListPage<WebCheckin>> fetchEventRelatedCheckins({
    required String eventId,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/checkins',
      queryParameters: {
        'page': page.clamp(1, 1 << 31),
        'limit': limit.clamp(1, 100),
        if (eventId.trim().isNotEmpty) 'eventId': eventId.trim(),
      },
    );
    final pageData = LiveApiPayload.listPage<WebCheckin>(
      response.data,
      WebCheckin.fromJson,
    );
    final pagination = response.extra[kPaginationExtraKey];
    if (pagination is Map<String, dynamic>) {
      return pageData.copyWith(pagination: BFFPagination.fromJson(pagination));
    }
    return pageData;
  }

  Future<void> reportEvent({
    required String eventId,
    required String reason,
    String? detail,
  }) async {
    await _dio.post<void>(
      '/v1/reports',
      data: {
        'targetType': 'event',
        'targetId': eventId,
        'reason': reason,
        if (detail != null && detail.trim().isNotEmpty) 'detail': detail.trim(),
        'source': 'flutter_event_detail',
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Event CRUD
  // ---------------------------------------------------------------------------

  Future<WebEvent> createEvent(Map<String, dynamic> payload) async {
    final response = await _dio.post<dynamic>(
      '/v1/events',
      data: payload,
    );
    return WebEvent.fromJson(LiveApiPayload.object(response.data));
  }

  Future<WebEvent> updateEvent(String id, Map<String, dynamic> payload) async {
    final response = await _dio.put<dynamic>(
      '/v1/events/$id',
      data: payload,
    );
    return WebEvent.fromJson(LiveApiPayload.object(response.data));
  }

  Future<void> deleteEvent(String id) async {
    await _dio.delete<void>('/v1/events/$id');
  }

  Future<String> uploadEventPoster(
    String localPath, {
    String? eventId,
    String? draftId,
    String? usage,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(localPath),
      if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
      if (draftId != null && draftId.isNotEmpty) 'draftId': draftId,
      if (usage != null && usage.isNotEmpty) 'usage': usage,
    });
    final response = await _dio.post<dynamic>(
      '/v1/events/upload-image',
      data: formData,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
    return _urlFromUploadPayload(
      response.data,
      fallbackError: 'Event image upload response did not include a URL.',
    );
  }

  // ---------------------------------------------------------------------------
  // Lineup Import (AI OCR)
  // ---------------------------------------------------------------------------

  /// Upload a lineup poster image for AI OCR DJ matching.
  Future<List<LineupImportMatch>> importLineupFromImage({
    required File imageFile,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(imageFile.path),
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    });
    final response = await _dio.post<dynamic>(
      '/v1/events/lineup/import-image',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return LiveApiPayload.items(
      response.data,
      itemKeys: const [
        'lineupInfo',
        'lineup_info',
        'matches',
        'items',
        'list',
        'data',
      ],
    )
        .whereType<Map<String, dynamic>>()
        .map(LineupImportMatch.fromJson)
        .where((match) => match.djName.trim().isNotEmpty)
        .toList();
  }
}

String? _firstString(Map<String, dynamic> json, Iterable<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

double? _numberAsDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _urlFromUploadPayload(dynamic payload, {required String fallbackError}) {
  final object = LiveApiPayload.object(payload);
  final url = object['url'] ??
      object['imageUrl'] ??
      object['imageURL'] ??
      object['posterUrl'] ??
      object['posterURL'];
  if (url is String && url.isNotEmpty) return url;
  throw StateError(fallbackError);
}
