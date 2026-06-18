import 'package:dio/dio.dart';
import 'package:feature_circle/src/ratings/data/rating_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_models/raver_models.dart';

void main() {
  group('RatingApi list', () {
    test('omits status query when loading the native all-events hub', () async {
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
                      'items': <Map<String, dynamic>>[],
                      'pagination': {
                        'page': 1,
                        'limit': 20,
                        'total': 0,
                        'totalPages': 1,
                      },
                    },
                  },
                ),
              );
            },
          ),
        );

      final page = await RatingApi(dio).fetchRatings(
        page: 1,
        limit: 20,
      );

      expect(page.items, isEmpty);
      expect(request.path, '/v1/rating-events');
      expect(request.queryParameters, {
        'page': 1,
        'limit': 20,
      });
    });
  });

  group('RatingApi share links', () {
    test('resolves rating event share payload with live target seed', () async {
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
                      'code': 'abc',
                      'shortUrl': 'https://ravehub.top/s/abc',
                    },
                  },
                ),
              );
            },
          ),
        );

      const event = WebRatingEvent(
        id: 'rating-1',
        name: 'Best Stage',
        description: 'Vote the night',
        imageUrl: 'https://cdn.example.com/rating.jpg',
        eventId: 'event-1',
        eventName: 'RaveHub Night',
        creatorId: 'user-1',
        createdAt: '2026-06-17T00:00:00Z',
      );

      final payload = await RatingApi(dio).resolveRatingEventShareLink(
        event: event,
        channel: 'system_share',
      );

      expect(request.path, '/v1/share-links/resolve');
      expect(payload.shortUrl, 'https://ravehub.top/s/abc');
      final body = request.data as Map<String, dynamic>;
      expect(body['targetType'], 'rating_event');
      expect(body['targetId'], 'rating-1');
      expect(body['channel'], 'system_share');
      expect(body['preferPermanent'], isTrue);
      final seed = body['targetSeed'] as Map<String, dynamic>;
      expect(seed['title'], 'Best Stage');
      expect(seed['subtitle'], 'Vote the night');
      expect(seed['imageUrl'], 'https://cdn.example.com/rating.jpg');
      expect(
          seed['canonicalUrl'], 'https://ravehub.top/circle/ratings/rating-1');
      expect(seed['deepLink'], 'raver://circle/ratings/rating-1');
      expect(
          seed['fallbackUrl'], 'https://ravehub.top/circle/ratings/rating-1');
      expect(seed['previewType'], 'rating_event_card');
      expect(seed['visibility'], 'public');
    });

    test('resolves rating unit share payload with live target seed', () async {
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
                      'code': 'unit',
                      'shortUrl': 'https://ravehub.top/s/unit',
                    },
                  },
                ),
              );
            },
          ),
        );

      const unit = WebRatingUnit(
        id: 'unit-1',
        name: 'Main Stage',
        description: 'Peak hour set',
        imageUrl: 'https://cdn.example.com/unit.jpg',
        djId: 'dj-1',
        djName: 'DJ One',
        djAvatarUrl: '',
        rating: 8.8,
        ratingCount: 42,
        commentCount: 3,
        createdAt: '2026-06-17T00:00:00Z',
      );

      final payload = await RatingApi(dio).resolveRatingUnitShareLink(
        ratingId: 'rating-1',
        unit: unit,
        channel: 'system_share',
      );

      expect(request.path, '/v1/share-links/resolve');
      expect(payload.shortUrl, 'https://ravehub.top/s/unit');
      final body = request.data as Map<String, dynamic>;
      expect(body['targetType'], 'rating_unit');
      expect(body['targetId'], 'unit-1');
      final seed = body['targetSeed'] as Map<String, dynamic>;
      expect(seed['title'], 'Main Stage');
      expect(seed['subtitle'], 'Peak hour set');
      expect(seed['imageUrl'], 'https://cdn.example.com/unit.jpg');
      expect(
        seed['canonicalUrl'],
        'https://ravehub.top/circle/ratings/rating-1/units/unit-1',
      );
      expect(
        seed['deepLink'],
        'raver://circle/ratings/rating-1/units/unit-1',
      );
      expect(seed['previewType'], 'rating_unit_card');
      expect(seed['visibility'], 'public');
    });
  });
}
