import 'package:dio/dio.dart';
import 'package:feature_profile/src/checkins/data/checkin_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_models/raver_models.dart';

void main() {
  group('CheckinApi share links', () {
    test('resolves my checkins share payload with live target seed', () async {
      late RequestOptions request;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              request = options;
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: {
                    'data': {
                      'code': 'checkins',
                      'shortUrl': 'https://ravehub.top/s/checkins',
                    },
                  },
                ),
              );
            },
          ),
        );

      const overview = MyCheckinsOverviewResponse(
        stats: MyCheckinsOverviewStats(
          totalCheckins: 12,
          uniqueEvents: 8,
          uniqueDJs: 21,
          totalDays: 5,
        ),
        timeline: [],
        gallerySummary: MyCheckinsOverviewGallerySummary(
          eventCount: 8,
          artistCount: 21,
        ),
      );

      final payload = await CheckinApi(dio).resolveMyCheckinsShareLink(
        overview: overview,
        channel: 'system_share',
      );

      expect(request.path, '/v1/share-links/resolve');
      expect(payload.shortUrl, 'https://ravehub.top/s/checkins');
      final body = request.data as Map<String, dynamic>;
      expect(body['targetType'], 'my_checkins');
      expect(body['targetId'], 'me');
      expect(body['channel'], 'system_share');
      expect(body['preferPermanent'], isTrue);
      final seed = body['targetSeed'] as Map<String, dynamic>;
      expect(seed['title'], 'RaveHub Check-ins');
      expect(seed['subtitle'], '12 check-ins · 8 events · 21 DJs');
      expect(seed['canonicalUrl'], 'https://ravehub.top/profile/checkins');
      expect(seed['deepLink'], 'raver://profile/checkins');
      expect(seed['fallbackUrl'], 'https://ravehub.top/profile/checkins');
      expect(seed['previewType'], 'my_checkins_card');
      expect(seed['visibility'], 'private');
    });
  });
}
