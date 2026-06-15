import 'dart:io';

import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

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

  factory LineupImportMatch.fromJson(Map<String, dynamic> json) =>
      LineupImportMatch(
        djName: json['djName'] as String,
        djId: json['djId'] as String?,
        confidence: (json['confidence'] as num).toDouble(),
        avatarUrl: json['avatarUrl'] as String?,
      );
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

    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/events',
      queryParameters: queryParameters,
    );

    return BFFListPage.fromJson(
      response.data!,
      (json) => WebEvent.fromJson(json! as Map<String, dynamic>),
    );
  }

  Future<List<WebEvent>> fetchRecommendedEvents({
    required int limit,
    List<String>? statuses,
  }) async {
    final queryParameters = <String, dynamic>{
      'limit': limit,
      if (statuses != null) 'statuses': statuses.join(','),
    };

    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/events/recommendations',
      queryParameters: queryParameters,
    );

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => WebEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WebEvent> fetchEvent({required String id}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/events/$id',
    );
    return WebEvent.fromJson(response.data!);
  }

  Future<WebEvent> fetchEventSummary({required String id}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/events/$id/summary',
    );
    return WebEvent.fromJson(response.data!);
  }

  Future<List<WebEventLineupArtist>> fetchEventLineup({
    required String eventId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/events/$eventId/lineup',
    );
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => WebEventLineupArtist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<WebEventLineupSlot>> fetchEventTimetable({
    required String eventId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/events/$eventId/timetable',
    );
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => WebEventLineupSlot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EventFavoriteStatus> fetchFavoriteStatus({
    required String eventId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/events/$eventId/favorite',
    );
    return EventFavoriteStatus.fromJson(response.data!);
  }

  Future<EventFavoriteStatus> favoriteEvent({
    required String eventId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/events/$eventId/favorite',
    );
    return EventFavoriteStatus.fromJson(response.data!);
  }

  Future<void> unfavoriteEvent({required String eventId}) async {
    await _dio.delete<void>('/v1/events/$eventId/favorite');
  }

  Future<GlobalSearchResponse> searchGlobal({
    required String query,
    required String tab,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/search/global',
      queryParameters: {
        'query': query,
        'tab': tab,
        'limit': limit,
      },
    );
    return GlobalSearchResponse.fromJson(response.data!);
  }

  // ---------------------------------------------------------------------------
  // Discussion
  // ---------------------------------------------------------------------------

  Future<EventDiscussionPage> fetchDiscussion({
    required String eventId,
    String? cursor,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/events/$eventId/discussion',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
      },
    );
    return EventDiscussionPage.fromJson(response.data!);
  }

  Future<EventDiscussionComment> postComment({
    required String eventId,
    required String content,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/events/$eventId/discussion',
      data: {'content': content},
    );
    return EventDiscussionComment.fromJson(response.data!);
  }

  // ---------------------------------------------------------------------------
  // Check-in
  // ---------------------------------------------------------------------------

  Future<EventCheckinResult> checkin({
    required String eventId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/events/$eventId/checkin',
    );
    return EventCheckinResult.fromJson(response.data!);
  }

  Future<EventCheckinList> fetchCheckins({
    required String eventId,
    int limit = 10,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/events/$eventId/checkins',
      queryParameters: {'limit': limit},
    );
    return EventCheckinList.fromJson(response.data!);
  }

  // ---------------------------------------------------------------------------
  // Event CRUD
  // ---------------------------------------------------------------------------

  Future<WebEvent> createEvent(Map<String, dynamic> payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/events',
      data: payload,
    );
    return WebEvent.fromJson(response.data!);
  }

  Future<WebEvent> updateEvent(String id, Map<String, dynamic> payload) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/v1/events/$id',
      data: payload,
    );
    return WebEvent.fromJson(response.data!);
  }

  Future<void> deleteEvent(String id) async {
    await _dio.delete<void>('/v1/events/$id');
  }

  Future<String> uploadEventPoster(String localPath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(localPath),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/upload/events/poster',
      data: formData,
    );
    return response.data!['url'] as String;
  }

  // ---------------------------------------------------------------------------
  // Lineup Import (AI OCR)
  // ---------------------------------------------------------------------------

  /// Upload a lineup poster image for AI OCR DJ matching.
  ///
  /// Sends the image to `POST /v1/events/{eventId}/lineup/import-image`
  /// and returns a list of matched DJs with confidence scores.
  Future<List<LineupImportMatch>> importLineupFromImage({
    required String eventId,
    required File imageFile,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(imageFile.path),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/events/$eventId/lineup/import-image',
      data: formData,
    );
    final items = response.data!['matches'] as List<dynamic>? ?? [];
    return items
        .map((e) => LineupImportMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
