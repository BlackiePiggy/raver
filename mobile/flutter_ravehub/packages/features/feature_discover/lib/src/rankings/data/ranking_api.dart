import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

final rankingApiProvider = Provider<RankingApi>((ref) {
  throw UnimplementedError(
    'rankingApiProvider must be overridden with a Dio instance',
  );
});

class RankingApi {
  RankingApi(this._dio);
  final Dio _dio;

  Future<List<RankingBoard>> fetchRankings() async {
    final response =
        await _dio.get<List<dynamic>>('/v1/learn/rankings');
    final list = response.data ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(RankingBoard.fromJson)
        .toList();
  }

  Future<RankingBoardDetail> fetchRankingDetail(
    String boardId, {
    int? year,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/learn/rankings/$boardId',
      queryParameters: {if (year != null) 'year': year},
    );
    return RankingBoardDetail.fromJson(response.data!);
  }
}
