import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:feature_discover/src/events/data/events_api_service.dart';
import 'package:feature_discover/src/events/presentation/view_models/event_upload_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('addLineupEntries merges imported DJs and skips duplicates', () {
    final viewModel = EventUploadViewModel(
      api: EventsApiService(Dio()),
    );
    addTearDown(viewModel.dispose);

    viewModel.addLineupEntry(djName: 'AKI');

    final added = viewModel.addLineupEntries([
      LineupEntry(djName: ' aki '),
      LineupEntry(djId: 'dj-2', djName: 'Bass Runner'),
      LineupEntry(djId: 'dj-2', djName: 'Bass Runner Alt'),
      LineupEntry(djName: ''),
    ]);

    expect(added, 1);
    expect(viewModel.lineup, hasLength(2));
    expect(viewModel.lineup.first.djName, 'AKI');
    expect(viewModel.lineup.last.djId, 'dj-2');
    expect(viewModel.lineup.last.djName, 'Bass Runner');
  });

  test('fillLineupFromSchedule adds missing timetable DJs only', () {
    final viewModel = EventUploadViewModel(
      api: EventsApiService(Dio()),
    );
    addTearDown(viewModel.dispose);

    viewModel.addLineupEntry(djName: 'AKI');
    viewModel.addScheduleEntry(
      stageName: 'Main',
      djName: 'AKI',
      startTime: DateTime(2026, 7, 1, 22),
      endTime: DateTime(2026, 7, 1, 23),
    );
    viewModel.addScheduleEntry(
      stageName: 'Main',
      djId: 'dj-2',
      djName: 'Bass Runner',
      startTime: DateTime(2026, 7, 1, 23),
      endTime: DateTime(2026, 7, 2),
    );

    expect(viewModel.lineupArtistsMissingFromSchedule, ['Bass Runner']);
    expect(viewModel.fillLineupFromSchedule(), 1);
    expect(viewModel.lineupArtistsMissingFromSchedule, isEmpty);
    expect(viewModel.lineup.map((entry) => entry.djName), [
      'AKI',
      'Bass Runner',
    ]);
  });

  test('buildCreatePayload emits iOS-style schedule and lineup slot contract',
      () {
    final viewModel = EventUploadViewModel(
      api: EventsApiService(Dio()),
    );
    addTearDown(viewModel.dispose);

    viewModel
      ..title = 'RaveHub Night'
      ..description = 'Warehouse session'
      ..eventType = 'warehouse'
      ..startDate = DateTime(2026, 7, 1, 20)
      ..endDate = DateTime(2026, 7, 2, 4)
      ..timezone = 'Asia/Shanghai'
      ..venueName = 'Dada'
      ..venueCity = 'Shanghai'
      ..venueCountry = 'CN';
    viewModel.addLineupEntry(djId: 'dj-1', djName: 'AKI');
    viewModel.addScheduleEntry(
      stageName: 'Main',
      djId: 'dj-1',
      djName: 'AKI',
      startTime: DateTime(2026, 7, 1, 23, 30),
      endTime: DateTime(2026, 7, 1, 1),
    );

    final payload = viewModel.buildCreatePayload();

    expect(payload['startDate'], '2026-07-01');
    expect(payload['endDate'], '2026-07-02');
    expect(payload['timeZone'], 'Asia/Shanghai');
    expect(payload['stageOrder'], ['Main']);
    expect(payload['lineupSyncMode'], 'incremental_fill');

    final schedule = payload['schedule'] as Map<String, dynamic>;
    expect(schedule, {
      'mode': 'multi_day',
      'timeZone': 'Asia/Shanghai',
      'dayRolloverHour': 6,
    });

    final weeks = payload['weeks'] as List<dynamic>;
    expect(weeks.single, {
      'id': 'draft-week-1',
      'weekIndex': 1,
      'startDate': '2026-07-01',
      'endDate': '2026-07-02',
      'sortOrder': 1,
    });

    final eventDays = payload['eventDays'] as List<dynamic>;
    expect(eventDays, hasLength(2));
    expect(eventDays.first, containsPair('eventDayId', 'd1'));
    expect(eventDays.last, containsPair('eventDayId', 'd2'));

    final artists = payload['lineupArtists'] as List<dynamic>;
    expect(artists.single, {
      'djId': 'dj-1',
      'memberDjIds': ['dj-1'],
      'memberNames': ['AKI'],
      'djName': 'AKI',
      'sortOrder': 1,
    });

    final slots = payload['lineupSlots'] as List<dynamic>;
    expect(slots.single, {
      'eventDayId': 'd1',
      'weekIndex': 1,
      'dayIndexInWeek': 1,
      'overallDayIndex': 1,
      'localDate': '2026-07-01',
      'djId': 'dj-1',
      'memberDjIds': ['dj-1'],
      'memberNames': ['AKI'],
      'djName': 'AKI',
      'stageName': 'Main',
      'sortOrder': 1,
      'startTime': '2026-07-01T23:30:00',
      'endTime': '2026-07-02T01:00:00',
    });
  });

  test('schedule editor filters and moves slots across day and stage', () {
    final viewModel = EventUploadViewModel(
      api: EventsApiService(Dio()),
    );
    addTearDown(viewModel.dispose);

    viewModel
      ..startDate = DateTime(2026, 7, 1, 20)
      ..endDate = DateTime(2026, 7, 3, 4)
      ..timezone = 'Asia/Shanghai';
    viewModel.addScheduleEntry(
      stageName: 'Main',
      djName: 'AKI',
      startTime: DateTime(2026, 7, 1, 22),
      endTime: DateTime(2026, 7, 1, 23),
    );
    viewModel.addScheduleEntry(
      stageName: 'Room 2',
      djName: 'Bass Runner',
      startTime: DateTime(2026, 7, 2, 1),
      endTime: DateTime(2026, 7, 2, 2),
    );

    expect(viewModel.scheduleDayOptions.map((day) => day.key), [
      '2026-07-01',
      '2026-07-02',
      '2026-07-03',
    ]);
    expect(viewModel.scheduleStageOptions, ['Main', 'Room 2']);

    viewModel.selectScheduleDay('2026-07-02');
    expect(viewModel.visibleScheduleEntries.single.entry.djName, 'Bass Runner');

    viewModel.selectScheduleStage('Main');
    expect(viewModel.visibleScheduleEntries, isEmpty);

    viewModel.moveScheduleEntry(
      index: 0,
      dayKey: '2026-07-02',
      stageName: 'Room 2',
    );

    viewModel.selectScheduleStage('Room 2');
    final movedEntry = viewModel.visibleScheduleEntries
        .firstWhere((item) => item.entry.djName == 'AKI')
        .entry;
    expect(movedEntry.startTime, DateTime(2026, 7, 2, 22));

    final payload = viewModel.buildCreatePayload();
    expect(payload['stageOrder'], ['Room 2']);
    final slots = payload['lineupSlots'] as List<dynamic>;
    expect(slots.first['localDate'], '2026-07-02');
    expect(slots.first['stageName'], 'Room 2');
  });

  test('image upload zones emit cover, lineup, and imageAssets payload',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('event-upload-images');
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
            expect(options.method, 'POST');
            expect(options.path, '/v1/events/upload-image');
            final formData = options.data as FormData;
            usages.add(
              formData.fields.firstWhere((entry) => entry.key == 'usage').value,
            );
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'url': 'https://cdn.ravehub.top/events/${usages.last}.jpg',
                  },
                },
              ),
            );
          },
        ),
      );
    final viewModel = EventUploadViewModel(api: EventsApiService(dio));
    addTearDown(viewModel.dispose);

    await viewModel.uploadEventImage(EventUploadImageZone.poster, poster.path);
    await viewModel.uploadEventImage(EventUploadImageZone.lineup, lineup.path);
    await viewModel.uploadEventImage(EventUploadImageZone.cover, cover.path);

    expect(usages, ['poster', 'lineup', 'cover']);
    final payload = viewModel.buildCreatePayload();
    expect(
        payload['coverImageUrl'], 'https://cdn.ravehub.top/events/poster.jpg');
    expect(
        payload['lineupImageUrl'], 'https://cdn.ravehub.top/events/lineup.jpg');

    final assets = payload['imageAssets'] as List<dynamic>;
    expect(assets, [
      {
        'url': 'https://cdn.ravehub.top/events/poster.jpg',
        'type': 'poster',
        'label': 'POSTER',
        'sort': 1,
        'order': 1,
        'source': 'flutter-event-upload',
        'fileName': 'poster.jpg',
      },
      {
        'url': 'https://cdn.ravehub.top/events/lineup.jpg',
        'type': 'luall',
        'label': 'LINE-UP',
        'sort': 2,
        'order': 2,
        'source': 'flutter-event-upload',
        'fileName': 'lineup.jpg',
      },
      {
        'url': 'https://cdn.ravehub.top/events/cover.jpg',
        'type': 'cover',
        'label': 'COVER',
        'sort': 3,
        'order': 3,
        'source': 'flutter-event-upload',
        'fileName': 'cover.jpg',
      },
    ]);
  });

  test('image upload supports multi-image reorder remove and draft restore',
      () async {
    SharedPreferences.setMockInitialValues({});
    final tempDir =
        await Directory.systemTemp.createTemp('event-upload-multi-images');
    final posterA = File('${tempDir.path}/poster-a.jpg');
    final posterB = File('${tempDir.path}/poster-b.jpg');
    final cover = File('${tempDir.path}/cover.jpg');
    await posterA.writeAsBytes([1]);
    await posterB.writeAsBytes([2]);
    await cover.writeAsBytes([3]);
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    var uploadCount = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final formData = options.data as FormData;
            final usage = formData.fields
                .firstWhere((entry) => entry.key == 'usage')
                .value;
            uploadCount += 1;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'url':
                        'https://cdn.ravehub.top/events/$usage-$uploadCount.jpg',
                  },
                },
              ),
            );
          },
        ),
      );
    const draftKey = 'event-upload-multi-image-draft';
    final viewModel = EventUploadViewModel(
      api: EventsApiService(dio),
      draftKey: draftKey,
    );
    addTearDown(viewModel.dispose);

    await viewModel.uploadEventImage(EventUploadImageZone.poster, posterA.path);
    await viewModel.uploadEventImage(EventUploadImageZone.poster, posterB.path);
    await viewModel.uploadEventImage(EventUploadImageZone.cover, cover.path);

    expect(viewModel.imageAssetsFor(EventUploadImageZone.poster), hasLength(2));
    expect(viewModel.posterUrl, 'https://cdn.ravehub.top/events/poster-1.jpg');

    viewModel.reorderImageAsset(
      EventUploadImageZone.poster,
      oldIndex: 1,
      newIndex: 0,
    );
    expect(viewModel.posterUrl, 'https://cdn.ravehub.top/events/poster-2.jpg');

    var payload = viewModel.buildCreatePayload();
    expect(
      payload['coverImageUrl'],
      'https://cdn.ravehub.top/events/poster-2.jpg',
    );
    expect(
      (payload['imageAssets'] as List<dynamic>).map((item) => item['url']),
      [
        'https://cdn.ravehub.top/events/poster-2.jpg',
        'https://cdn.ravehub.top/events/poster-1.jpg',
        'https://cdn.ravehub.top/events/cover-3.jpg',
      ],
    );

    viewModel.removeImageAsset(EventUploadImageZone.poster, 0);
    expect(viewModel.posterUrl, 'https://cdn.ravehub.top/events/poster-1.jpg');

    await viewModel.saveDraft();
    final restored = EventUploadViewModel(
      api: EventsApiService(Dio()),
      draftKey: draftKey,
    );
    addTearDown(restored.dispose);
    expect(await restored.restoreDraft(), isTrue);
    expect(restored.imageAssetsFor(EventUploadImageZone.poster), hasLength(1));
    expect(restored.posterUrl, 'https://cdn.ravehub.top/events/poster-1.jpg');

    payload = restored.buildCreatePayload();
    expect(
      (payload['imageAssets'] as List<dynamic>).map((item) => item['order']),
      [1, 2],
    );
  });

  test('image upload tracks progress and retries failed uploads', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('event-upload-retry-image');
    final poster = File('${tempDir.path}/poster.jpg');
    await poster.writeAsBytes([1]);
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    var attempt = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            attempt += 1;
            options.onSendProgress?.call(1, 4);
            if (attempt == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  message: 'upload failed',
                ),
              );
              return;
            }
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'url': 'https://cdn.ravehub.top/events/retried.jpg',
                  },
                },
              ),
            );
          },
        ),
      );
    final viewModel = EventUploadViewModel(api: EventsApiService(dio));
    addTearDown(viewModel.dispose);

    await viewModel.uploadEventImage(EventUploadImageZone.poster, poster.path);

    final failedState =
        viewModel.imageUploadStateFor(EventUploadImageZone.poster);
    expect(failedState?.phase, EventUploadImageUploadPhase.failed);
    expect(failedState?.canRetry, isTrue);
    expect(failedState?.progress, 0.25);
    expect(viewModel.posterUrl, isNull);

    await viewModel.retryImageUpload(EventUploadImageZone.poster);

    expect(viewModel.imageUploadStateFor(EventUploadImageZone.poster), isNull);
    expect(viewModel.posterUrl, 'https://cdn.ravehub.top/events/retried.jpg');
  });

  test('image upload can be cancelled without adding an asset', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('event-upload-cancel-image');
    final poster = File('${tempDir.path}/poster.jpg');
    await poster.writeAsBytes([1]);
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final requestStarted = Completer<RequestOptions>();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.onSendProgress?.call(1, 2);
            requestStarted.complete(options);
            Future<void>.delayed(const Duration(milliseconds: 20), () {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.cancel,
                  message: 'cancelled',
                ),
              );
            });
          },
        ),
      );
    final viewModel = EventUploadViewModel(api: EventsApiService(dio));
    addTearDown(viewModel.dispose);

    final upload = viewModel.uploadEventImage(
      EventUploadImageZone.poster,
      poster.path,
    );
    await requestStarted.future;
    viewModel.cancelImageUpload(EventUploadImageZone.poster);
    await upload;

    final state = viewModel.imageUploadStateFor(EventUploadImageZone.poster);
    expect(state?.phase, EventUploadImageUploadPhase.cancelled);
    expect(state?.canRetry, isTrue);
    expect(viewModel.imageAssetsFor(EventUploadImageZone.poster), isEmpty);
  });

  test('saveDraft and restoreDraft persist upload state locally', () async {
    SharedPreferences.setMockInitialValues({});
    final draftKey = 'event-upload-test-draft';
    final viewModel = EventUploadViewModel(
      api: EventsApiService(Dio()),
      draftKey: draftKey,
    );
    addTearDown(viewModel.dispose);

    viewModel
      ..title = 'Saved Rave'
      ..description = 'Draft body'
      ..eventType = 'festival'
      ..startDate = DateTime(2026, 8, 1, 18)
      ..endDate = DateTime(2026, 8, 2, 3)
      ..timezone = 'Asia/Tokyo'
      ..venueName = 'Unit'
      ..venueCity = 'Tokyo'
      ..venueCountry = 'JP'
      ..venueLatitude = 35.6
      ..venueLongitude = 139.7
      ..ticketUrl = 'https://tickets.example/rave'
      ..maxCapacity = 800;
    viewModel
      ..addLineupEntry(djId: 'dj-1', djName: 'AKI')
      ..addScheduleEntry(
        stageName: 'Main',
        djName: 'AKI',
        startTime: DateTime(2026, 8, 1, 22),
        endTime: DateTime(2026, 8, 2),
      )
      ..nextStep();
    await viewModel.saveDraft();

    final restored = EventUploadViewModel(
      api: EventsApiService(Dio()),
      draftKey: draftKey,
    );
    addTearDown(restored.dispose);

    expect(await restored.restoreDraft(), isTrue);
    expect(restored.hasRestoredDraft, isTrue);
    expect(restored.currentStep, EventUploadStep.poster);
    expect(restored.title, 'Saved Rave');
    expect(restored.description, 'Draft body');
    expect(restored.eventType, 'festival');
    expect(restored.startDate, DateTime(2026, 8, 1, 18));
    expect(restored.endDate, DateTime(2026, 8, 2, 3));
    expect(restored.timezone, 'Asia/Tokyo');
    expect(restored.venueName, 'Unit');
    expect(restored.venueCity, 'Tokyo');
    expect(restored.venueCountry, 'JP');
    expect(restored.venueLatitude, 35.6);
    expect(restored.venueLongitude, 139.7);
    expect(restored.ticketUrl, 'https://tickets.example/rave');
    expect(restored.maxCapacity, 800);
    expect(restored.lineup.single.djName, 'AKI');
    expect(restored.schedule.single.stageName, 'Main');
    expect(restored.lastSavedAt, isNotNull);
  });

  test('submit clears saved draft after live create succeeds', () async {
    SharedPreferences.setMockInitialValues({});
    final draftKey = 'event-upload-submit-clears-draft';
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/v1/events') {
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': {
                      'id': 'event-1',
                      'name': 'Saved Rave',
                      'slug': 'saved-rave',
                      'description': '',
                      'eventType': 'festival',
                      'startDate': '2026-08-01',
                      'endDate': '2026-08-02',
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
    final viewModel = EventUploadViewModel(
      api: EventsApiService(dio),
      draftKey: draftKey,
    );
    addTearDown(viewModel.dispose);

    viewModel
      ..title = 'Saved Rave'
      ..eventType = 'festival'
      ..startDate = DateTime(2026, 8, 1)
      ..endDate = DateTime(2026, 8, 2)
      ..venueName = 'Unit';
    await viewModel.saveDraft();
    final beforeSubmitRestore = EventUploadViewModel(
      api: EventsApiService(Dio()),
      draftKey: draftKey,
    );
    addTearDown(beforeSubmitRestore.dispose);
    expect(
      await beforeSubmitRestore.restoreDraft(),
      isTrue,
    );

    expect(await viewModel.submit(), isTrue);

    expect(viewModel.isSubmitted, isTrue);
    expect(viewModel.createdEvent?.id, 'event-1');
    final restored = EventUploadViewModel(
      api: EventsApiService(Dio()),
      draftKey: draftKey,
    );
    addTearDown(restored.dispose);
    expect(await restored.restoreDraft(), isFalse);
  });

  test('submit validates required fields and routes to the first issue',
      () async {
    var requestCount = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount += 1;
            handler.reject(DioException(requestOptions: options));
          },
        ),
      );
    final viewModel = EventUploadViewModel(api: EventsApiService(dio));
    addTearDown(viewModel.dispose);
    viewModel.goToStep(EventUploadStep.tickets);

    expect(await viewModel.submit(), isFalse);
    expect(requestCount, 0);
    expect(viewModel.currentStep, EventUploadStep.basicInfo);
    expect(viewModel.validationIssues.map((issue) => issue.fieldLabel), [
      'Title',
      'Start',
      'End',
      'Venue',
    ]);
  });

  test('discardDraft clears saved data and resets restored form state',
      () async {
    SharedPreferences.setMockInitialValues({});
    final draftKey = 'event-upload-discard-draft';
    final viewModel = EventUploadViewModel(
      api: EventsApiService(Dio()),
      draftKey: draftKey,
    );
    addTearDown(viewModel.dispose);

    viewModel
      ..title = 'Discard Me'
      ..venueName = 'Basement'
      ..startDate = DateTime(2026, 8, 1)
      ..endDate = DateTime(2026, 8, 2)
      ..addLineupEntry(djName: 'AKI')
      ..nextStep();
    await viewModel.saveDraft();

    expect(await viewModel.restoreDraft(), isTrue);
    await viewModel.discardDraft();

    expect(viewModel.hasRestoredDraft, isFalse);
    expect(viewModel.title, isEmpty);
    expect(viewModel.venueName, isEmpty);
    expect(viewModel.lineup, isEmpty);
    expect(viewModel.currentStep, EventUploadStep.basicInfo);

    final restored = EventUploadViewModel(
      api: EventsApiService(Dio()),
      draftKey: draftKey,
    );
    addTearDown(restored.dispose);
    expect(await restored.restoreDraft(), isFalse);
  });
}
