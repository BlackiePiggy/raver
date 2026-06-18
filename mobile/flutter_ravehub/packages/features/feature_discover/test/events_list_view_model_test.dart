import 'package:dio/dio.dart';
import 'package:feature_discover/src/events/data/events_api_service.dart';
import 'package:feature_discover/src/events/data/events_repository.dart';
import 'package:feature_discover/src/events/presentation/view_models/events_list_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_models/raver_models.dart';

void main() {
  group('EventsListViewModel', () {
    test('keeps search query across initial load and pagination', () async {
      final requests = <Map<String, dynamic>>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(Map<String, dynamic>.from(options.queryParameters));
              final page = options.queryParameters['page'] as int;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: _page(
                    [_event('event-$page', 'Event $page')],
                    page: page,
                    totalPages: 2,
                  ),
                ),
              );
            },
          ),
        );
      final viewModel = _viewModel(dio);
      addTearDown(viewModel.dispose);

      await viewModel.setSearchQuery(' techno ');
      await Future.wait([viewModel.loadMore(), viewModel.loadMore()]);

      expect(requests, hasLength(2));
      expect(requests[0]['page'], 1);
      expect(requests[0]['search'], 'techno');
      expect(requests[1]['page'], 2);
      expect(requests[1]['search'], 'techno');
      expect(viewModel.events.map((event) => event.id), ['event-1', 'event-2']);
      expect(viewModel.canLoadMore, isFalse);
    });

    test('refresh failure preserves the current non-empty list', () async {
      var requestCount = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requestCount += 1;
              if (requestCount > 1) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    message: 'temporary failure',
                  ),
                );
                return;
              }
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: _page(
                    [_event('event-1', 'Stable Event')],
                    page: 1,
                    totalPages: 1,
                  ),
                ),
              );
            },
          ),
        );
      final viewModel = _viewModel(dio);
      addTearDown(viewModel.dispose);

      await viewModel.load();
      await viewModel.refresh();

      expect(viewModel.events.map((event) => event.id), ['event-1']);
      expect(viewModel.isRefreshing, isFalse);
    });

    test('event type filter is sent to the live events endpoint', () async {
      final requests = <Map<String, dynamic>>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(Map<String, dynamic>.from(options.queryParameters));
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: _page(
                    [_event('bar-event-1', 'Bar Event')],
                    page: 1,
                    totalPages: 1,
                  ),
                ),
              );
            },
          ),
        );
      final viewModel = _viewModel(dio);
      addTearDown(viewModel.dispose);

      await viewModel.setEventTypeFilter(EventTypeFilter.barEvent);

      expect(requests.single['eventType'], 'bar_event');
      expect(viewModel.events.single.id, 'bar-event-1');
    });

    test('status filter is sent to the live events endpoint', () async {
      final requests = <Map<String, dynamic>>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(Map<String, dynamic>.from(options.queryParameters));
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: _page(
                    [_event('ongoing-event-1', 'Ongoing Event')],
                    page: 1,
                    totalPages: 1,
                  ),
                ),
              );
            },
          ),
        );
      final viewModel = _viewModel(dio);
      addTearDown(viewModel.dispose);

      await viewModel.setStatusFilter(EventStatusFilter.ongoing);

      expect(requests.single['status'], 'ongoing');
      expect(viewModel.events.single.id, 'ongoing-event-1');
    });

    test('advanced filters combine type status and supporting search terms',
        () async {
      final requests = <Map<String, dynamic>>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(Map<String, dynamic>.from(options.queryParameters));
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: _page(
                    [_event('filtered-event-1', 'Filtered Event')],
                    page: 1,
                    totalPages: 1,
                  ),
                ),
              );
            },
          ),
        );
      final viewModel = _viewModel(dio);
      addTearDown(viewModel.dispose);

      await viewModel.setSearchQuery('techno');
      await viewModel.applyAdvancedFilters(
        eventTypes: [EventTypeFilter.festival, EventTypeFilter.warehouse],
        status: EventStatusFilter.upcoming,
        city: 'Shanghai',
        brand: 'RaveHub',
      );

      expect(requests, hasLength(2));
      expect(requests.last['search'], 'techno Shanghai RaveHub');
      expect(requests.last['eventType'], 'festival,warehouse');
      expect(requests.last['status'], 'upcoming');
      expect(viewModel.events.single.id, 'filtered-event-1');
    });

    test('toggleFavorite posts to live service and updates list state',
        () async {
      final requests = <String>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add('${options.method} ${options.path}');
              if (options.path == '/v1/events') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: _page(
                      [
                        _event(
                          'event-1',
                          'Favorite Event',
                          isFavorited: false,
                          favoriteCount: 2,
                        ),
                      ],
                      page: 1,
                      totalPages: 1,
                    ),
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
      await viewModel.toggleFavorite('event-1');

      expect(requests, ['GET /v1/events', 'POST /v1/events/event-1/favorite']);
      expect(viewModel.events.single.isFavorited, isTrue);
      expect(viewModel.events.single.favoriteCount, 3);
    });

    test('toggleFavorite deletes live favorite and rolls back on failure',
        () async {
      var shouldFailDelete = true;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/v1/events') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: _page(
                      [
                        _event(
                          'event-1',
                          'Favorite Event',
                          isFavorited: true,
                          favoriteCount: 4,
                        ),
                      ],
                      page: 1,
                      totalPages: 1,
                    ),
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
      await viewModel.toggleFavorite('event-1');

      expect(viewModel.events.single.isFavorited, isTrue);
      expect(viewModel.events.single.favoriteCount, 4);

      shouldFailDelete = false;
      await viewModel.toggleFavorite('event-1');

      expect(viewModel.events.single.isFavorited, isFalse);
      expect(viewModel.events.single.favoriteCount, 3);
    });
  });
}

EventsListViewModel _viewModel(Dio dio) {
  return EventsListViewModel(
    repository: EventsRepository(EventsApiService(dio)),
  );
}

Map<String, dynamic> _page(
  List<Map<String, dynamic>> items, {
  required int page,
  required int totalPages,
}) {
  return {
    'items': items,
    'pagination': {
      'page': page,
      'limit': 20,
      'total': items.length,
      'totalPages': totalPages,
    },
  };
}

Map<String, dynamic> _event(
  String id,
  String name, {
  bool? isFavorited,
  int favoriteCount = 0,
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
      )
      .toJson();
}
