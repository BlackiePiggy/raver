import 'package:dio/dio.dart';
import 'package:feature_discover/src/events/data/event_manual_cache_store.dart';
import 'package:feature_discover/src/events/data/events_api_service.dart';
import 'package:feature_discover/src/events/data/events_repository.dart';
import 'package:feature_discover/src/events/presentation/view_models/event_detail_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_models/raver_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EventDetailViewModel', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('toggleFavorite posts to live service and updates event state',
        () async {
      final requests = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add('${options.method} ${options.path}');
              if (options.path == '/v1/events/event-1') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: _event(
                      'event-1',
                      'Favorite Event',
                      isFavorited: false,
                      favoriteCount: 2,
                      checkinCount: 1,
                    ),
                  ),
                );
                return;
              }
              if (options.path == '/v1/events/event-1/lineup' ||
                  options.path == '/v1/events/event-1/timetable') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {'items': []},
                  ),
                );
                return;
              }
              if (options.path == '/v1/events/event-1/checkins') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'data': {'items': [], 'total_count': 1},
                    },
                  ),
                );
                return;
              }
              if (options.path == '/v1/checkins') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'data': {
                        'items': [_checkinJson('checkin-1')],
                      },
                    },
                  ),
                );
                return;
              }
              if (options.path == '/v1/feed') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'data': {
                        'posts': [_postJson('post-1')],
                      },
                    },
                  ),
                );
                return;
              }
              if (options.path == '/v1/news/bound') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'data': {
                        'articles': [_newsJson('news-1')],
                      },
                    },
                  ),
                );
                return;
              }
              if (options.path == '/v1/dj-sets') {
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
                return;
              }
              if (options.path == '/v1/events/event-1/rating-events') {
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
                return;
              }
              if (options.path == '/v1/events/event-1/favorite') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {'is_favorited': true},
                  ),
                );
                return;
              }
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );
      final viewModel = _viewModel(dio);
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await viewModel.toggleFavorite();

      expect(requests, [
        'GET /v1/events/event-1',
        'GET /v1/events/event-1/lineup',
        'GET /v1/events/event-1/timetable',
        'GET /v1/events/event-1/checkins',
        'GET /v1/checkins',
        'GET /v1/feed',
        'GET /v1/news/bound',
        'GET /v1/dj-sets',
        'GET /v1/events/event-1/rating-events',
        'POST /v1/events/event-1/favorite',
      ]);
      expect(viewModel.relatedPosts.single.id, 'post-1');
      expect(viewModel.relatedNews.single.id, 'news-1');
      expect(viewModel.relatedSets.single.id, 'set-1');
      expect(viewModel.relatedRatingEvents.single.id, 'rating-1');
      expect(viewModel.relatedCheckins.single.id, 'checkin-1');
      expect(viewModel.isFavorited, isTrue);
      expect(viewModel.event?.isFavorited, isTrue);
      expect(viewModel.event?.favoriteCount, 3);
      expect(viewModel.errorMessage, isNull);
    });

    test('toggleFavorite deletes live favorite and rolls back on failure',
        () async {
      var shouldFailDelete = true;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/v1/events/event-1') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: _event(
                      'event-1',
                      'Favorite Event',
                      isFavorited: true,
                      favoriteCount: 4,
                      checkinCount: 2,
                    ),
                  ),
                );
                return;
              }
              if (options.path == '/v1/events/event-1/lineup' ||
                  options.path == '/v1/events/event-1/timetable') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {'items': []},
                  ),
                );
                return;
              }
              if (options.path == '/v1/events/event-1/checkins') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'data': {'items': [], 'total_count': 2},
                    },
                  ),
                );
                return;
              }
              if (options.path == '/v1/checkins') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'data': {'items': []},
                    },
                  ),
                );
                return;
              }
              if (options.path == '/v1/feed') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'data': {'posts': []},
                    },
                  ),
                );
                return;
              }
              if (options.path == '/v1/news/bound') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'data': {'articles': []},
                    },
                  ),
                );
                return;
              }
              if (options.path == '/v1/dj-sets') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'data': {'items': []},
                    },
                  ),
                );
                return;
              }
              if (options.path == '/v1/events/event-1/rating-events') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'data': {'items': []},
                    },
                  ),
                );
                return;
              }
              if (options.path == '/v1/events/event-1/favorite' &&
                  shouldFailDelete) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    message: 'delete failed',
                  ),
                );
                return;
              }
              handler.resolve(
                Response<void>(requestOptions: options, statusCode: 204),
              );
            },
          ),
        );
      final viewModel = _viewModel(dio);
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await viewModel.toggleFavorite();

      expect(viewModel.isFavorited, isTrue);
      expect(viewModel.event?.isFavorited, isTrue);
      expect(viewModel.event?.favoriteCount, 4);
      expect(viewModel.errorMessage, contains('delete failed'));

      shouldFailDelete = false;
      await viewModel.toggleFavorite();

      expect(viewModel.isFavorited, isFalse);
      expect(viewModel.event?.isFavorited, isFalse);
      expect(viewModel.event?.favoriteCount, 3);
    });

    test('checkin posts to live service and updates status and event count',
        () async {
      final requests = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add('${options.method} ${options.path}');
              if (options.path == '/v1/events/event-1') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: _event(
                      'event-1',
                      'Checkin Event',
                      isFavorited: false,
                      favoriteCount: 2,
                      checkinCount: 1,
                    ),
                  ),
                );
                return;
              }
              if (options.path == '/v1/events/event-1/lineup' ||
                  options.path == '/v1/events/event-1/timetable') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {'items': []},
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
                        'users': [],
                        'total_count': 5,
                        'my_checkin_at': null,
                      },
                    },
                  ),
                );
                return;
              }
              if (options.method == 'GET' && options.path == '/v1/checkins') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'data': {
                        'items': [_checkinJson('checkin-1')],
                      },
                    },
                  ),
                );
                return;
              }
              if (options.method == 'GET' && options.path == '/v1/feed') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'data': {
                        'posts': [_postJson('post-1')],
                      },
                    },
                  ),
                );
                return;
              }
              if (options.method == 'GET' && options.path == '/v1/news/bound') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'data': {
                        'articles': [_newsJson('news-1')],
                      },
                    },
                  ),
                );
                return;
              }
              if (options.method == 'GET' && options.path == '/v1/dj-sets') {
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
                return;
              }
              if (options.method == 'GET' &&
                  options.path == '/v1/events/event-1/rating-events') {
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
                return;
              }
              if (options.method == 'POST' &&
                  options.path == '/v1/events/event-1/checkin') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'data': {
                        'checkin_id': 'checkin-1',
                        'checked_in_at': '2026-07-01T20:30:00Z',
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
      final viewModel = _viewModel(dio);
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.event?.checkinCount, 5);
      expect(viewModel.hasCheckedIn, isFalse);

      await viewModel.checkin();

      expect(requests, [
        'GET /v1/events/event-1',
        'GET /v1/events/event-1/lineup',
        'GET /v1/events/event-1/timetable',
        'GET /v1/events/event-1/checkins',
        'GET /v1/checkins',
        'GET /v1/feed',
        'GET /v1/news/bound',
        'GET /v1/dj-sets',
        'GET /v1/events/event-1/rating-events',
        'POST /v1/events/event-1/checkin',
      ]);
      expect(viewModel.relatedPosts.single.content, 'Warehouse was packed.');
      expect(viewModel.relatedNews.single.title, 'RaveHub Night Recap');
      expect(viewModel.relatedSets.single.title, 'Warehouse Closing Set');
      expect(viewModel.relatedRatingEvents.single.name, 'RaveHub Night Rating');
      expect(viewModel.relatedCheckins.first.id, 'checkin-1');
      expect(viewModel.hasCheckedIn, isTrue);
      expect(viewModel.myCheckinAt, '2026-07-01T20:30:00Z');
      expect(viewModel.event?.checkinCount, 6);
      expect(viewModel.relatedCheckins.first.id, 'checkin-1');
      expect(viewModel.relatedCheckins, hasLength(2));
      expect(viewModel.errorMessage, isNull);
    });

    test('manual cache is used when live event detail is offline', () async {
      var liveShouldFail = false;
      final requests = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add('${options.method} ${options.path}');
              if (options.path == '/v1/events/event-1') {
                if (liveShouldFail) {
                  handler.reject(
                    DioException(
                      requestOptions: options,
                      type: DioExceptionType.connectionError,
                      error: 'offline',
                    ),
                  );
                  return;
                }
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: _event(
                      'event-1',
                      'Cached Event',
                      isFavorited: true,
                      favoriteCount: 7,
                      checkinCount: 3,
                    ),
                  ),
                );
                return;
              }
              if (options.path == '/v1/events/event-1/lineup' ||
                  options.path == '/v1/events/event-1/timetable') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {'items': []},
                  ),
                );
                return;
              }
              if (options.path == '/v1/events/event-1/checkins') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'data': {'items': [], 'total_count': 3},
                    },
                  ),
                );
                return;
              }
              if (options.path == '/v1/checkins' ||
                  options.path == '/v1/feed' ||
                  options.path == '/v1/news/bound' ||
                  options.path == '/v1/dj-sets' ||
                  options.path == '/v1/events/event-1/rating-events') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'data': {'items': [], 'posts': [], 'articles': []},
                    },
                  ),
                );
                return;
              }
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );
      final viewModel = _viewModel(dio);
      addTearDown(viewModel.dispose);

      await viewModel.load();
      final cachedAt = await viewModel.cacheCurrentEvent();
      liveShouldFail = true;
      await viewModel.load();

      expect(cachedAt, isNotNull);
      expect(viewModel.event?.name, 'Cached Event');
      expect(viewModel.isFavorited, isTrue);
      expect(viewModel.isShowingCachedEvent, isTrue);
      expect(viewModel.manualCachedAt, cachedAt);
      expect(
        requests.where((request) => request == 'GET /v1/events/event-1'),
        hasLength(2),
      );
    });
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

EventDetailViewModel _viewModel(
  Dio dio, {
  EventManualCacheStore? manualCacheStore,
}) {
  return EventDetailViewModel(
    eventId: 'event-1',
    repository: EventsRepository(EventsApiService(dio)),
    manualCacheStore: manualCacheStore,
  );
}

Map<String, dynamic> _event(
  String id,
  String name, {
  bool? isFavorited,
  int favoriteCount = 0,
  int checkinCount = 0,
}) {
  return const WebEvent(
    id: '',
    name: '',
    slug: '',
    description: '',
    coverImageUrl: '',
    lineupImageUrl: '',
    eventType: '',
    startDate: '',
    endDate: '',
    favoriteCount: 0,
    checkinCount: 0,
  )
      .copyWith(
        id: id,
        name: name,
        slug: id,
        isFavorited: isFavorited,
        favoriteCount: favoriteCount,
        checkinCount: checkinCount,
      )
      .toJson();
}
