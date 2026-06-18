import 'dart:io';

import 'package:dio/dio.dart';
import 'package:feature_discover/src/events/data/events_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_models/raver_models.dart';

void main() {
  test('fetchEventPosts uses live feed event filter query', () async {
    Map<String, dynamic>? capturedQuery;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'GET');
            expect(options.path, '/v1/feed');
            capturedQuery = Map<String, dynamic>.from(
              options.queryParameters,
            );
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'posts': [_postJson('post-1')],
                    'nextCursor': 'cursor-2',
                  },
                },
              ),
            );
          },
        ),
      );

    final page = await EventsApiService(dio).fetchEventPosts(
      eventId: 'event-1',
      limit: 12,
      mode: 'latest',
      cursor: 'cursor-1',
    );

    expect(capturedQuery, {
      'limit': 12,
      'mode': 'latest',
      'eventId': 'event-1',
      'cursor': 'cursor-1',
    });
    expect(page.nextCursor, 'cursor-2');
    expect(page.posts.single.id, 'post-1');
    expect(page.posts.single.eventId, 'event-1');
  });

  test('fetchEventSets uses iOS live event set query', () async {
    Map<String, dynamic>? capturedQuery;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'GET');
            expect(options.path, '/v1/dj-sets');
            capturedQuery = Map<String, dynamic>.from(
              options.queryParameters,
            );
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'items': [_setJson('set-1')],
                  },
                },
              ),
            );
          },
        ),
      );

    final sets = await EventsApiService(dio).fetchEventSets(
      eventId: 'event-1',
      eventName: 'RaveHub Night',
      limit: 200,
    );

    expect(capturedQuery, {
      'page': 1,
      'limit': 200,
      'sortBy': 'latest',
      'eventId': 'event-1',
      'eventName': 'RaveHub Night',
    });
    expect(sets.single.id, 'set-1');
    expect(sets.single.eventId, 'event-1');
  });

  test('fetchEventRatingEvents uses iOS live event rating endpoint', () async {
    Map<String, dynamic>? capturedQuery;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'GET');
            expect(options.path, '/v1/events/event-1/rating-events');
            capturedQuery = Map<String, dynamic>.from(
              options.queryParameters,
            );
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'items': [_ratingJson('rating-1')],
                  },
                },
              ),
            );
          },
        ),
      );

    final ratings = await EventsApiService(dio).fetchEventRatingEvents(
      eventId: 'event-1',
      page: 2,
      limit: 12,
    );

    expect(capturedQuery, {'page': 2, 'limit': 12});
    expect(ratings.single.id, 'rating-1');
    expect(ratings.single.eventId, 'event-1');
  });

  test('fetchEventNews uses iOS live bound news endpoint', () async {
    Map<String, dynamic>? capturedQuery;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'GET');
            expect(options.path, '/v1/news/bound');
            capturedQuery = Map<String, dynamic>.from(
              options.queryParameters,
            );
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'articles': [_newsJson('news-1')],
                    'nextCursor': 'cursor-2',
                  },
                },
              ),
            );
          },
        ),
      );

    final page = await EventsApiService(dio).fetchEventNews(
      eventId: 'event-1',
      limit: 12,
      cursor: 'cursor-1',
    );

    expect(capturedQuery, {
      'limit': 12,
      'eventId': 'event-1',
      'cursor': 'cursor-1',
    });
    expect(page.nextCursor, 'cursor-2');
    expect(page.articles.single.id, 'news-1');
    expect(page.articles.single.boundEventIds, ['event-1']);
  });

  test('fetchEventRelatedCheckins uses iOS live checkin event filter',
      () async {
    Map<String, dynamic>? capturedQuery;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'GET');
            expect(options.path, '/v1/checkins');
            capturedQuery = Map<String, dynamic>.from(
              options.queryParameters,
            );
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'items': [_checkinJson('checkin-1')],
                  },
                  'pagination': {
                    'page': 1,
                    'limit': 12,
                    'total': 1,
                  },
                },
              ),
            );
          },
        ),
      );

    final page = await EventsApiService(dio).fetchEventRelatedCheckins(
      eventId: 'event-1',
      page: 1,
      limit: 12,
    );

    expect(capturedQuery, {'page': 1, 'limit': 12, 'eventId': 'event-1'});
    expect(page.items.single.id, 'checkin-1');
    expect(page.items.single.eventId, 'event-1');
    expect(page.items.single.eventName, 'RaveHub Night');
    expect(page.items.single.eventCoverUrl,
        'https://cdn.ravehub.top/events/event-1.jpg');
  });

  test('event check-in APIs parse iOS live snake_case payloads', () async {
    final requests = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add('${options.method} ${options.path}');
            if (options.method == 'POST' &&
                options.path == '/v1/events/event-1/checkin') {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {
                    'data': {
                      'success': true,
                      'checkin_id': 'checkin-1',
                      'checked_in_at': '2026-07-01T20:30:00Z',
                    },
                  },
                ),
              );
              return;
            }
            if (options.method == 'GET' &&
                options.path == '/v1/events/event-1/checkins') {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {
                    'data': {
                      'users': [
                        {
                          'user_id': 'user-1',
                          'display_name': 'Aki',
                          'avatar_url': 'https://cdn.ravehub.top/u/1.jpg',
                          'checked_in_at': '2026-07-01T20:30:00Z',
                        },
                      ],
                      'total_count': '12',
                      'my_checkin_at': '2026-07-01T20:30:00Z',
                    },
                  },
                ),
              );
              return;
            }
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
    final service = EventsApiService(dio);

    final result = await service.checkin(eventId: 'event-1');
    final checkins = await service.fetchCheckins(eventId: 'event-1');

    expect(requests, [
      'POST /v1/events/event-1/checkin',
      'GET /v1/events/event-1/checkins',
    ]);
    expect(result.checkinId, 'checkin-1');
    expect(result.checkedInAt, '2026-07-01T20:30:00Z');
    expect(checkins.totalCount, 12);
    expect(checkins.myCheckinAt, '2026-07-01T20:30:00Z');
    expect(checkins.users.single.userId, 'user-1');
    expect(checkins.users.single.displayName, 'Aki');
    expect(checkins.users.single.avatarUrl, 'https://cdn.ravehub.top/u/1.jpg');
  });

  test('reportEvent posts iOS-style report payload to live reports endpoint',
      () async {
    Map<String, dynamic>? capturedBody;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'POST');
            expect(options.path, '/v1/reports');
            capturedBody = Map<String, dynamic>.from(
              options.data as Map<String, dynamic>,
            );
            handler.resolve(
              Response<void>(requestOptions: options, statusCode: 204),
            );
          },
        ),
      );

    await EventsApiService(dio).reportEvent(
      eventId: 'event-1',
      reason: 'spam',
      detail: 'duplicate listing',
    );

    expect(capturedBody, {
      'targetType': 'event',
      'targetId': 'event-1',
      'reason': 'spam',
      'detail': 'duplicate listing',
      'source': 'flutter_event_detail',
    });
  });

  test('importLineupFromImage uses iOS live global OCR endpoint', () async {
    final tempDir = await Directory.systemTemp.createTemp('lineup-import-test');
    final imageFile = File('${tempDir.path}/lineup.jpg');
    await imageFile.writeAsBytes([1, 2, 3]);
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    late FormData capturedFormData;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'POST');
            expect(options.path, '/v1/events/lineup/import-image');
            capturedFormData = options.data as FormData;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const {
                  'data': {
                    'normalizedText': 'AKI 22:00 Main',
                    'lineupInfo': [
                      {
                        'id': 'slot-1',
                        'musician': 'AKI',
                        'confidence': '0.73',
                      },
                      {
                        'dj_name': 'Bass Runner',
                        'dj_id': 'dj-2',
                        'avatar_url': 'https://cdn.ravehub.top/djs/dj-2.jpg',
                      },
                    ],
                  },
                },
              ),
            );
          },
        ),
      );

    final matches = await EventsApiService(dio).importLineupFromImage(
      imageFile: imageFile,
      startDate: DateTime.utc(2026, 7, 1, 20),
      endDate: DateTime.utc(2026, 7, 2, 4),
    );

    expect(capturedFormData.files.single.key, 'image');
    expect(
      Map<String, String>.fromEntries(capturedFormData.fields),
      {
        'startDate': '2026-07-01T20:00:00.000Z',
        'endDate': '2026-07-02T04:00:00.000Z',
      },
    );
    expect(matches, hasLength(2));
    expect(matches.first.djName, 'AKI');
    expect(matches.first.confidence, 0.73);
    expect(matches.last.djId, 'dj-2');
    expect(matches.last.confidence, 1);
    expect(matches.last.avatarUrl, 'https://cdn.ravehub.top/djs/dj-2.jpg');
  });

  test('resolveShareLink posts event share payload to live resolver', () async {
    Map<String, dynamic>? capturedBody;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'POST');
            expect(options.path, '/v1/share-links/resolve');
            capturedBody = Map<String, dynamic>.from(
              options.data as Map<String, dynamic>,
            );
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const {
                  'data': {
                    'code': 'event123',
                    'url': 'https://ravehub.top/s/event123',
                    'shortUrl': 'https://ravehub.top/s/event123',
                  },
                },
              ),
            );
          },
        ),
      );

    final payload = await EventsApiService(dio).resolveShareLink(
      event: const WebEvent(
        id: 'event-1',
        name: 'RaveHub Night',
        slug: 'ravehub-night',
        description: 'Warehouse session',
        coverImageUrl: 'https://cdn.ravehub.top/events/event-1.jpg',
        lineupImageUrl: '',
        eventType: 'warehouse',
        startDate: '2026-07-01',
        endDate: '2026-07-01',
        favoriteCount: 1,
        checkinCount: 2,
      ),
    );

    expect(payload.shortUrl, 'https://ravehub.top/s/event123');
    expect(capturedBody?['targetType'], 'event');
    expect(capturedBody?['targetId'], 'event-1');
    expect(capturedBody?['channel'], 'system_share');
    expect(capturedBody?['preferPermanent'], isTrue);
    final seed = capturedBody?['targetSeed'] as Map<String, dynamic>;
    expect(seed['title'], 'RaveHub Night');
    expect(seed['subtitle'], 'Warehouse session');
    expect(seed['imageUrl'], 'https://cdn.ravehub.top/events/event-1.jpg');
    expect(seed['canonicalUrl'], 'https://ravehub.top/events/event-1');
    expect(seed['deepLink'], 'raver://events/event-1');
    expect(seed['fallbackUrl'], 'https://ravehub.top/events/event-1');
    expect(seed['previewType'], 'event_card');
  });
}

Map<String, dynamic> _newsJson(String id) {
  return {
    'id': id,
    'title': 'RaveHub Night Recap',
    'summary': 'A packed warehouse night.',
    'body': 'Long form article body',
    'category': 'event',
    'source': 'RaveHub',
    'coverImageUrl': 'https://cdn.ravehub.top/news/$id.jpg',
    'authorId': 'user-1',
    'authorName': 'Editor',
    'boundEventIds': ['event-1'],
    'replyCount': 4,
    'createdAt': '2026-07-02T10:00:00Z',
  };
}

Map<String, dynamic> _setJson(String id) {
  return {
    'id': id,
    'djId': 'dj-1',
    'djName': 'Bass Runner',
    'title': 'Warehouse Closing Set',
    'videoUrl': 'https://cdn.ravehub.top/sets/$id.mp4',
    'platform': 'upload',
    'videoId': id,
    'duration': 3600,
    'recordedAt': '2026-07-01T23:00:00Z',
    'venue': 'Dada Shanghai',
    'eventId': 'event-1',
    'eventName': 'RaveHub Night',
    'thumbnailUrl': 'https://cdn.ravehub.top/sets/$id.jpg',
    'commentCount': 2,
    'likeCount': 8,
    'createdAt': '2026-07-02T08:00:00Z',
  };
}

Map<String, dynamic> _ratingJson(String id) {
  return {
    'id': id,
    'name': 'RaveHub Night Rating',
    'description': 'Vote for the best set.',
    'imageUrl': 'https://cdn.ravehub.top/ratings/$id.jpg',
    'eventId': 'event-1',
    'eventName': 'RaveHub Night',
    'creatorId': 'user-1',
    'createdAt': '2026-07-02T08:00:00Z',
  };
}

Map<String, dynamic> _postJson(String id) {
  return {
    'id': id,
    'content': 'Warehouse was packed.',
    'images': ['https://cdn.ravehub.top/posts/$id.jpg'],
    'user': {
      'id': 'user-1',
      'username': 'bassrunner',
      'displayName': 'Bass Runner',
      'avatarUrl': 'https://cdn.ravehub.top/users/user-1.jpg',
    },
    'likeCount': 3,
    'commentCount': 2,
    'repostCount': 0,
    'saveCount': 1,
    'shareCount': 0,
    'eventId': 'event-1',
    'eventName': 'RaveHub Night',
    'createdAt': '2026-07-01T20:30:00Z',
  };
}

Map<String, dynamic> _checkinJson(String id) {
  return {
    'id': id,
    'user_id': 'user-1',
    'event_id': 'event-1',
    'event': {
      'name': 'RaveHub Night',
      'cover_image_url': 'https://cdn.ravehub.top/events/event-1.jpg',
    },
    'type': 'event',
    'note': 'Front row all night',
    'rating': '5',
    'attended_at': '2026-07-01T20:30:00Z',
    'created_at': '2026-07-01T21:00:00Z',
  };
}
