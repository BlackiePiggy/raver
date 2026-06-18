import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class SearchApiService {
  SearchApiService(this._dio);

  final Dio _dio;

  Future<GlobalSearchResponse> searchGlobal({
    required String query,
    required String tab,
    required int limit,
    String locale = 'en',
  }) async {
    final keyword = query.trim();
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/search',
      queryParameters: {
        if (keyword.isNotEmpty) 'q': keyword,
        'tab': tab,
        'limit': limit.clamp(1, 80),
        'locale': locale,
      },
    );
    return GlobalSearchResponse.fromJson(response.data!);
  }
}
