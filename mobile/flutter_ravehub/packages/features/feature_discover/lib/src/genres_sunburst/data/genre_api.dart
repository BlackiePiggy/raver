import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

import '../../_shared/discover_dio.dart';

final genreApiProvider = Provider<GenreApi>((ref) {
  return GenreApi(ref.watch(discoverDioProvider));
});

class GenreApi {
  GenreApi(this._dio);
  final Dio _dio;

  Future<List<GenreSunburstNode>> fetchSunburstTree() async {
    final response = await _dio.get<dynamic>('/v1/learn/genres');
    return LiveApiPayload.items(
      response.data,
    )
        .whereType<Map<String, dynamic>>()
        .map(GenreSunburstNode.fromJson)
        .toList();
  }

  Future<LearnGenreNode> fetchGenreDetail(String genreId) async {
    final response = await _dio.get<dynamic>(
      '/v1/learn/genres/$genreId',
    );
    return LearnGenreNode.fromJson(LiveApiPayload.object(response.data));
  }
}
