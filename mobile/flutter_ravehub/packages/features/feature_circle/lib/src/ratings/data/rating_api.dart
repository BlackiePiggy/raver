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
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/ratings',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (status != null) 'status': status,
      },
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) => WebRatingEvent.fromJson(json! as Map<String, dynamic>),
    );
  }

  Future<WebRatingEvent> createRatingEvent({
    required String name,
    required String description,
    required String eventId,
    String? imageUrl,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/social/ratings',
      data: {
        'name': name,
        'description': description,
        'eventId': eventId,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
    );
    return WebRatingEvent.fromJson(response.data!);
  }

  Future<WebRatingEvent> fetchRatingEvent({required String id}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/ratings/$id',
    );
    return WebRatingEvent.fromJson(response.data!);
  }

  Future<List<WebRatingUnit>> fetchRatingUnits({
    required String ratingId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/ratings/$ratingId/units',
    );
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => WebRatingUnit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WebRatingUnit> createRatingUnit({
    required String ratingId,
    required String name,
    required String djId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/social/ratings/$ratingId/units',
      data: {
        'name': name,
        'djId': djId,
      },
    );
    return WebRatingUnit.fromJson(response.data!);
  }

  Future<void> voteRatingUnit({
    required String ratingId,
    required String unitId,
    required double score,
  }) async {
    await _dio.post<void>(
      '/v1/social/ratings/$ratingId/units/$unitId/vote',
      data: {'score': score},
    );
  }

  Future<BFFListPage<WebRatingComment>> fetchUnitComments({
    required String ratingId,
    required String unitId,
    required int page,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/ratings/$ratingId/units/$unitId/comments',
      queryParameters: {'page': page, 'limit': limit},
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) => WebRatingComment.fromJson(json! as Map<String, dynamic>),
    );
  }

  Future<WebRatingComment> postUnitComment({
    required String ratingId,
    required String unitId,
    required String content,
    required double score,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/social/ratings/$ratingId/units/$unitId/comments',
      data: {
        'content': content,
        'score': score,
      },
    );
    return WebRatingComment.fromJson(response.data!);
  }
}
