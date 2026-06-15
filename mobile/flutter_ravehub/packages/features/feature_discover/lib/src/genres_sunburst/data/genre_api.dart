import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

final genreApiProvider = Provider<GenreApi>((ref) {
  throw UnimplementedError(
    'genreApiProvider must be overridden with a Dio instance',
  );
});

class GenreApi {
  GenreApi(this._dio);
  final Dio _dio;

  Future<List<GenreSunburstNode>> fetchSunburstTree() async {
    final response = await _dio.get<List<dynamic>>('/v1/learn/genres');
    final list = response.data ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(GenreSunburstNode.fromJson)
        .toList();
  }

  Future<LearnGenreNode> fetchGenreDetail(String genreId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/v1/learn/genres/$genreId');
    return LearnGenreNode.fromJson(response.data!);
  }
}
