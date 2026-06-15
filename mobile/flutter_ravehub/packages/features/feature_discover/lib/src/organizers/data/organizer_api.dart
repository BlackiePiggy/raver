import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

final organizerApiProvider = Provider<OrganizerApi>((ref) {
  throw UnimplementedError(
    'organizerApiProvider must be overridden with a Dio instance',
  );
});

class OrganizerApi {
  OrganizerApi(this._dio);
  final Dio _dio;

  Future<List<LearnFestival>> fetchFestivals({int page = 1}) async {
    final response = await _dio.get<List<dynamic>>(
      '/v1/learn/festivals',
      queryParameters: {'page': page},
    );
    final list = response.data ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(LearnFestival.fromJson)
        .toList();
  }

  Future<LearnFestival> fetchFestivalDetail(String festivalId) async {
    final response = await _dio
        .get<Map<String, dynamic>>('/v1/learn/festivals/$festivalId');
    return LearnFestival.fromJson(response.data!);
  }

  /// Creates a new festival entry.
  Future<LearnFestival> createFestival(Map<String, dynamic> payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/learn/festivals',
      data: payload,
    );
    return LearnFestival.fromJson(response.data!);
  }

  /// Updates an existing festival entry.
  Future<LearnFestival> updateFestival(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/v1/learn/festivals/$id',
      data: payload,
    );
    return LearnFestival.fromJson(response.data!);
  }

  /// Uploads a festival cover image and returns the remote URL.
  Future<String> uploadFestivalCover(String localPath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(localPath),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/upload/festivals/cover',
      data: formData,
    );
    return response.data!['url'] as String;
  }
}
