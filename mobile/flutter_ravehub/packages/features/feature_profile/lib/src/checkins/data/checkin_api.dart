import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class CheckinApi {
  CheckinApi(this._dio);

  final Dio _dio;

  /// Fetch checkin list.
  Future<BFFListPage<WebCheckin>> fetchCheckins({
    required int page,
    int limit = 20,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/checkins',
      queryParameters: {'page': page, 'limit': limit},
    );
    return LiveApiPayload.listPage<WebCheckin>(
      response.data,
      WebCheckin.fromJson,
    );
  }

  /// Fetch checkin overview statistics.
  Future<MyCheckinsOverviewResponse> fetchOverview() async {
    final response = await _dio.get<dynamic>('/v2/me/checkins/overview');
    return MyCheckinsOverviewResponse.fromJson(
      LiveApiPayload.object(response.data),
    );
  }

  Future<ShareLinkPayload> resolveMyCheckinsShareLink({
    required MyCheckinsOverviewResponse overview,
    String channel = 'system_share',
  }) async {
    const canonicalUrl = 'https://ravehub.top/profile/checkins';
    final stats = overview.stats;
    final response = await _dio.post<dynamic>(
      '/v1/share-links/resolve',
      data: {
        'targetType': 'my_checkins',
        'targetId': 'me',
        'channel': channel,
        'preferPermanent': true,
        'targetSeed': {
          'title': 'RaveHub Check-ins',
          'subtitle':
              '${stats.totalCheckins} check-ins · ${stats.uniqueEvents} events · ${stats.uniqueDJs} DJs',
          'canonicalUrl': canonicalUrl,
          'deepLink': 'raver://profile/checkins',
          'fallbackUrl': canonicalUrl,
          'previewType': 'my_checkins_card',
          'visibility': 'private',
        },
      },
    );
    return ShareLinkPayload.fromJson(LiveApiPayload.object(response.data));
  }
}
