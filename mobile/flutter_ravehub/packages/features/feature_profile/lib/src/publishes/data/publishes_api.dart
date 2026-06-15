import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class PublishesApi {
  PublishesApi(this._dio);

  final Dio _dio;

  /// Fetch content submissions.
  Future<BFFListPage<ContentSubmissionSummary>> fetchSubmissions({
    required int page,
    int limit = 20,
    String? type,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/content-submissions',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (type != null) 'type': type,
      },
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) =>
          ContentSubmissionSummary.fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Fetch submission detail.
  Future<ContentSubmissionDetail> fetchSubmissionDetail({
    required String id,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/content-submissions/$id',
    );
    return ContentSubmissionDetail.fromJson(response.data!);
  }
}
