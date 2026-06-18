import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

import '../../_shared/discover_dio.dart';

final labelApiProvider = Provider<LabelApi>((ref) {
  return LabelApi(ref.watch(discoverDioProvider));
});

class LabelApi {
  LabelApi(this._dio);
  final Dio _dio;

  Future<List<LearnLabel>> fetchLabels({int page = 1}) async {
    final response = await _dio.get<dynamic>(
      '/v1/learn/labels',
      queryParameters: {'page': page},
    );
    return LiveApiPayload.items(
      response.data,
    ).whereType<Map<String, dynamic>>().map(LearnLabel.fromJson).toList();
  }

  Future<LearnLabel> fetchLabelDetail(String labelId) async {
    final response = await _dio.get<dynamic>(
      '/v1/learn/labels/$labelId',
    );
    return LearnLabel.fromJson(LiveApiPayload.object(response.data));
  }

  Future<ShareLinkPayload> resolveShareLink({
    required LearnLabel label,
    String channel = 'system_share',
  }) async {
    final url = 'https://ravehub.top/labels/${label.id}';
    final response = await _dio.post<dynamic>(
      '/v1/share-links/resolve',
      data: {
        'targetType': 'label',
        'targetId': label.id,
        'title': label.name,
        if (label.imageUrl.isNotEmpty) 'imageUrl': label.imageUrl,
        'url': url,
        'deepLink': 'raver://labels/${label.id}',
        'channel': channel,
      },
    );
    return ShareLinkPayload.fromJson(LiveApiPayload.object(response.data));
  }
}
