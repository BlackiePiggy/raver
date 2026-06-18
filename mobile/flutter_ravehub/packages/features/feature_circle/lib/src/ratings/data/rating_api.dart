import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class RatingApi {
  RatingApi(this._dio);

  final Dio _dio;

  Future<BFFListPage<WebRatingEvent>> fetchRatings({
    required int page,
    required int limit,
    String? status,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/rating-events',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (status != null) 'status': status,
      },
    );
    return LiveApiPayload.listPage<WebRatingEvent>(
      response.data,
      WebRatingEvent.fromJson,
    );
  }

  Future<WebRatingEvent> createRatingEvent({
    required String name,
    required String description,
    required String eventId,
    String? imageUrl,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/rating-events',
      data: {
        'name': name,
        'description': description,
        'eventId': eventId,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
    );
    return WebRatingEvent.fromJson(LiveApiPayload.object(response.data));
  }

  Future<WebRatingEvent> updateRatingEvent({
    required String id,
    required String name,
    required String description,
    String? imageUrl,
  }) async {
    final response = await _dio.patch<dynamic>(
      '/v1/rating-events/$id',
      data: {
        'name': name,
        'description': description,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
    );
    return WebRatingEvent.fromJson(LiveApiPayload.object(response.data));
  }

  Future<WebRatingEvent> fetchRatingEvent({required String id}) async {
    final response = await _dio.get<dynamic>('/v1/rating-events/$id');
    return WebRatingEvent.fromJson(LiveApiPayload.object(response.data));
  }

  Future<ShareLinkPayload> resolveRatingEventShareLink({
    required WebRatingEvent event,
    String channel = 'system_share',
  }) async {
    final canonicalUrl = 'https://ravehub.top/circle/ratings/${event.id}';
    final response = await _dio.post<dynamic>(
      '/v1/share-links/resolve',
      data: {
        'targetType': 'rating_event',
        'targetId': event.id,
        'channel': channel,
        'preferPermanent': true,
        'targetSeed': {
          'title': event.name,
          if (event.description.isNotEmpty) 'subtitle': event.description,
          if (event.imageUrl.isNotEmpty) 'imageUrl': event.imageUrl,
          'canonicalUrl': canonicalUrl,
          'deepLink': 'raver://circle/ratings/${event.id}',
          'fallbackUrl': canonicalUrl,
          'previewType': 'rating_event_card',
          'visibility': 'public',
        },
      },
    );
    return ShareLinkPayload.fromJson(LiveApiPayload.object(response.data));
  }

  Future<List<WebRatingUnit>> fetchRatingUnits({
    required String ratingId,
  }) async {
    final response = await _dio.get<dynamic>('/v1/rating-events/$ratingId');
    final event = LiveApiPayload.object(response.data);
    final items = event['units'] as List<dynamic>? ?? [];
    return items
        .map((e) => WebRatingUnit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WebRatingUnit> fetchRatingUnit({required String unitId}) async {
    final response = await _dio.get<dynamic>('/v1/rating-units/$unitId');
    return WebRatingUnit.fromJson(LiveApiPayload.object(response.data));
  }

  Future<ShareLinkPayload> resolveRatingUnitShareLink({
    required String ratingId,
    required WebRatingUnit unit,
    String channel = 'system_share',
  }) async {
    final canonicalUrl =
        'https://ravehub.top/circle/ratings/$ratingId/units/${unit.id}';
    final response = await _dio.post<dynamic>(
      '/v1/share-links/resolve',
      data: {
        'targetType': 'rating_unit',
        'targetId': unit.id,
        'channel': channel,
        'preferPermanent': true,
        'targetSeed': {
          'title': unit.name,
          if (unit.description.isNotEmpty) 'subtitle': unit.description,
          if (unit.imageUrl.isNotEmpty) 'imageUrl': unit.imageUrl,
          'canonicalUrl': canonicalUrl,
          'deepLink': 'raver://circle/ratings/$ratingId/units/${unit.id}',
          'fallbackUrl': canonicalUrl,
          'previewType': 'rating_unit_card',
          'visibility': 'public',
        },
      },
    );
    return ShareLinkPayload.fromJson(LiveApiPayload.object(response.data));
  }

  Future<WebRatingUnit> updateRatingUnit({
    required String unitId,
    required String name,
    required String description,
    required String djId,
    String? imageUrl,
  }) async {
    final response = await _dio.patch<dynamic>(
      '/v1/rating-units/$unitId',
      data: {
        'name': name,
        'description': description,
        'djId': djId,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
    );
    return WebRatingUnit.fromJson(LiveApiPayload.object(response.data));
  }

  Future<WebRatingUnit> createRatingUnit({
    required String ratingId,
    required String name,
    required String djId,
    String description = '',
    String? imageUrl,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/rating-events/$ratingId/units',
      data: {
        'name': name,
        'description': description,
        'djId': djId,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
    );
    return WebRatingUnit.fromJson(LiveApiPayload.object(response.data));
  }

  Future<String> uploadRatingImage({
    required String localPath,
    String? ratingEventId,
    String? ratingUnitId,
    String? usage,
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(localPath),
      if (ratingEventId != null && ratingEventId.isNotEmpty)
        'ratingEventId': ratingEventId,
      if (ratingUnitId != null && ratingUnitId.isNotEmpty)
        'ratingUnitId': ratingUnitId,
      if (usage != null && usage.isNotEmpty) 'usage': usage,
    });
    final response = await _dio.post<dynamic>(
      '/v1/rating/upload-image',
      data: formData,
    );
    final object = LiveApiPayload.object(response.data);
    final url = object['url'] ?? object['imageUrl'] ?? object['imageURL'];
    if (url is String && url.isNotEmpty) return url;
    throw StateError('Rating image upload response did not include a URL.');
  }

  Future<void> voteRatingUnit({
    required String ratingId,
    required String unitId,
    required double score,
  }) async {
    await _dio.post<void>(
      '/v1/rating-units/$unitId/comments',
      data: {'score': score},
    );
  }

  Future<BFFListPage<WebRatingComment>> fetchUnitComments({
    required String ratingId,
    required String unitId,
    required int page,
    required int limit,
  }) async {
    final response = await _dio.get<dynamic>('/v1/rating-units/$unitId');
    final unit = LiveApiPayload.object(response.data);
    final items = unit['comments'] as List<dynamic>? ?? [];
    return BFFListPage<WebRatingComment>(
      items: items
          .map((e) => WebRatingComment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<WebRatingComment> postUnitComment({
    required String ratingId,
    required String unitId,
    required String content,
    required double score,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/rating-units/$unitId/comments',
      data: {'content': content, 'score': score},
    );
    return WebRatingComment.fromJson(LiveApiPayload.object(response.data));
  }
}
