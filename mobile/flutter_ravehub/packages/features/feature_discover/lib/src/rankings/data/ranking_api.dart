import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

import '../../_shared/discover_dio.dart';

final rankingApiProvider = Provider<RankingApi>((ref) {
  return RankingApi(ref.watch(discoverDioProvider));
});

class RankingApi {
  RankingApi(this._dio);
  final Dio _dio;

  Future<List<RankingBoard>> fetchRankings() async {
    final response = await _dio.get<dynamic>('/v1/learn/rankings');
    return LiveApiPayload.items(
      response.data,
    ).whereType<Map<String, dynamic>>().map(RankingBoard.fromJson).toList();
  }

  Future<RankingBoardDetail> fetchRankingDetail(
    String boardId, {
    int? year,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/learn/rankings/$boardId',
      queryParameters: {if (year != null) 'year': year},
    );
    return RankingBoardDetail.fromJson(LiveApiPayload.object(response.data));
  }

  Future<ShareLinkPayload> resolveShareLink({
    required RankingBoardDetail detail,
    String channel = 'system_share',
  }) async {
    final canonicalUrl =
        'https://ravehub.top/ranking-board/${detail.id}?year=${detail.year}';
    final response = await _dio.post<dynamic>(
      '/v1/share-links/resolve',
      data: {
        'targetType': 'ranking_board',
        'targetId': detail.id,
        'channel': channel,
        'preferPermanent': true,
        'targetSeed': {
          'title': detail.title,
          'subtitle': '${detail.year}',
          'canonicalUrl': canonicalUrl,
          'deepLink': 'raver://ranking-board/${detail.id}?year=${detail.year}',
          'fallbackUrl': canonicalUrl,
          'previewType': 'content_card',
          'visibility': 'public',
        },
      },
    );
    return ShareLinkPayload.fromJson(LiveApiPayload.object(response.data));
  }
}
