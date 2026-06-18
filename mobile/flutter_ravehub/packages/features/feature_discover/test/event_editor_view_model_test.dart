import 'dart:io';

import 'package:dio/dio.dart';
import 'package:feature_discover/src/events/data/events_api_service.dart';
import 'package:feature_discover/src/events/presentation/view_models/event_editor_view_model.dart';
import 'package:feature_discover/src/events/presentation/view_models/event_upload_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads event edit data and saves iOS-style schedule and media payload',
      () async {
    Map<String, dynamic>? savedPayload;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'GET' && options.path == '/v1/events/e-1') {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {
                      'id': 'e-1',
                      'name': 'Loaded Rave',
                      'slug': 'loaded-rave',
                      'description': 'Warehouse night',
                      'eventType': 'warehouse',
                      'startDate': '2026-07-01',
                      'endDate': '2026-07-02',
                      'coverImageUrl':
                          'https://cdn.ravehub.top/events/poster.jpg',
                      'lineupImageUrl':
                          'https://cdn.ravehub.top/events/lineup.jpg',
                      'schedule': {
                        'mode': 'multi_day',
                        'timeZone': 'Asia/Shanghai',
                      },
                      'location': {
                        'name': 'Dada',
                        'city': 'Shanghai',
                        'country': 'CN',
                        'latitude': 31.2,
                        'longitude': 121.4,
                      },
                      'lineupArtists': [
                        {
                          'id': 'la-1',
                          'djId': 'dj-1',
                          'name': 'AKI',
                          'isB2B': false,
                        },
                      ],
                      'lineupSlots': [
                        {
                          'id': 'slot-1',
                          'stageName': 'Main',
                          'djId': 'dj-1',
                          'artistName': 'AKI',
                          'startTime': '2026-07-01T23:30:00',
                          'endTime': '2026-07-02T01:00:00',
                        },
                      ],
                    },
                  },
                ),
              );
              return;
            }

            if (options.method == 'PUT' && options.path == '/v1/events/e-1') {
              savedPayload = Map<String, dynamic>.from(
                options.data as Map<String, dynamic>,
              );
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {
                      'id': 'e-1',
                      'name': savedPayload?['name'],
                      'slug': 'loaded-rave',
                      'description': savedPayload?['description'],
                      'eventType': savedPayload?['eventType'],
                      'startDate': savedPayload?['startDate'],
                      'endDate': savedPayload?['endDate'],
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
    final viewModel = EventEditorViewModel(
      api: EventsApiService(dio),
      eventId: 'e-1',
    );
    addTearDown(viewModel.dispose);

    await viewModel.loadEvent('e-1');
    expect(viewModel.title, 'Loaded Rave');
    expect(viewModel.posterUrl, 'https://cdn.ravehub.top/events/poster.jpg');
    expect(
        viewModel.lineupImageUrl, 'https://cdn.ravehub.top/events/lineup.jpg');
    expect(viewModel.lineup.single.djName, 'AKI');
    expect(viewModel.schedule.single.stageName, 'Main');

    await viewModel.save();

    expect(viewModel.isSaved, isTrue);
    expect(savedPayload, isNotNull);
    expect(savedPayload?['schedule'], {
      'mode': 'multi_day',
      'timeZone': 'Asia/Shanghai',
      'dayRolloverHour': 6,
    });
    expect(savedPayload?['stageOrder'], ['Main']);
    expect(savedPayload?['coverImageUrl'],
        'https://cdn.ravehub.top/events/poster.jpg');
    expect(savedPayload?['lineupImageUrl'],
        'https://cdn.ravehub.top/events/lineup.jpg');

    final assets = savedPayload?['imageAssets'] as List<dynamic>;
    expect(assets.map((item) => item['type']), ['poster', 'luall']);

    final artists = savedPayload?['lineupArtists'] as List<dynamic>;
    expect(artists.single['djName'], 'AKI');

    final slots = savedPayload?['lineupSlots'] as List<dynamic>;
    expect(slots.single['eventDayId'], 'd1');
    expect(slots.single['localDate'], '2026-07-01');
    expect(slots.single['stageName'], 'Main');
    expect(slots.single['startTime'], '2026-07-01T23:30:00');
    expect(slots.single['endTime'], '2026-07-02T01:00:00');
  });

  test('uploads edit image zones and keeps payload primary image semantics',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('event-edit-images');
    final poster = File('${tempDir.path}/poster.jpg');
    final lineup = File('${tempDir.path}/lineup.jpg');
    final cover = File('${tempDir.path}/cover.jpg');
    await poster.writeAsBytes([1]);
    await lineup.writeAsBytes([2]);
    await cover.writeAsBytes([3]);
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final usages = <String>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST' &&
                options.path == '/v1/events/upload-image') {
              final formData = options.data as FormData;
              final usage = formData.fields
                  .firstWhere((entry) => entry.key == 'usage')
                  .value;
              usages.add(usage);
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {
                      'url': 'https://cdn.ravehub.top/events/$usage.jpg',
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
    final viewModel = EventEditorViewModel(
      api: EventsApiService(dio),
      eventId: 'e-1',
    );
    addTearDown(viewModel.dispose);

    await viewModel.uploadEventImage(EventUploadImageZone.poster, poster.path);
    await viewModel.uploadEventImage(EventUploadImageZone.lineup, lineup.path);
    await viewModel.uploadEventImage(EventUploadImageZone.cover, cover.path);

    expect(usages, ['poster', 'lineup', 'cover']);
    expect(viewModel.posterUrl, 'https://cdn.ravehub.top/events/poster.jpg');
    expect(
        viewModel.lineupImageUrl, 'https://cdn.ravehub.top/events/lineup.jpg');
    expect(viewModel.coverImageUrl, 'https://cdn.ravehub.top/events/cover.jpg');

    var payload = viewModel.buildPayload();
    expect(
        payload['coverImageUrl'], 'https://cdn.ravehub.top/events/poster.jpg');
    expect(
        payload['lineupImageUrl'], 'https://cdn.ravehub.top/events/lineup.jpg');
    expect(
      (payload['imageAssets'] as List<dynamic>).map((item) => item['type']),
      ['poster', 'luall', 'cover'],
    );

    viewModel.removeImageAsset(EventUploadImageZone.poster);
    payload = viewModel.buildPayload();
    expect(
        payload['coverImageUrl'], 'https://cdn.ravehub.top/events/cover.jpg');
    expect(
      (payload['imageAssets'] as List<dynamic>).map((item) => item['type']),
      ['luall', 'cover'],
    );
  });
}
