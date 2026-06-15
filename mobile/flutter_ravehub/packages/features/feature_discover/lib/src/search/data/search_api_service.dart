import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class SearchApiService {
  SearchApiService(this._dio);

  final Dio _dio;

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
}
