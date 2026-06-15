import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class SetApi {
  final Dio _dio;

  SetApi(this._dio);

  Future<BFFListPage<WebDJSet>> fetchSets({
    int page = 1,
    int limit = 20,
    String sortBy = 'latest',
    String? djId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/sets',
      queryParameters: {
        'page': page,
        'limit': limit,
        'sortBy': sortBy,
        if (djId != null) 'djId': djId,
      },
    );
    final data = response.data!;
    final items = (data['items'] as List? ?? data['data'] as List? ?? [])
        .map((e) => WebDJSet.fromJson(e as Map<String, dynamic>))
        .toList();
    final pagination = data['pagination'] != null
        ? BFFPagination.fromJson(data['pagination'] as Map<String, dynamic>)
        : null;
    return BFFListPage(items: items, pagination: pagination);
  }

  Future<WebDJSet> fetchSet(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/sets/$id');
    return WebDJSet.fromJson(response.data!);
  }

  Future<List<WebSetComment>> fetchComments(
    String setId, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/v1/sets/$setId/comments',
      queryParameters: {'page': page, 'limit': limit},
    );
    return (response.data ?? [])
        .map((e) => WebSetComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WebSetComment> addComment(
    String setId, {
    required String content,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/sets/$setId/comments',
      data: {'content': content},
    );
    return WebSetComment.fromJson(response.data!);
  }

  Future<WebDJSet> createSet(Map<String, dynamic> payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/sets',
      data: payload,
    );
    return WebDJSet.fromJson(response.data!);
  }

  Future<WebDJSet> updateSet(String id, Map<String, dynamic> payload) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/v1/sets/$id',
      data: payload,
    );
    return WebDJSet.fromJson(response.data!);
  }

  Future<String> uploadSetAudio(String localPath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(localPath),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/upload/sets/audio',
      data: formData,
    );
    return response.data!['url'] as String;
  }

  Future<String> uploadSetVideo(String localPath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(localPath),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/upload/sets/video',
      data: formData,
    );
    return response.data!['url'] as String;
  }
}
