import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_platform/raver_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CountdownWidgetService', () {
    const channel = MethodChannel('home_widget');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('saves selected event data and refreshes native widgets', () async {
      await CountdownWidgetService.saveSelectedEvent(
        const CountdownWidgetEvent(
          id: 'event-1',
          name: 'Warehouse Night',
          startDateIso: '2026-07-01T20:00:00.000Z',
          venueName: 'Main Room',
        ),
      );

      expect(calls.first.method, 'setAppGroupId');
      expect(calls.first.arguments, {
        'groupId': CountdownWidgetService.appGroupId,
      });
      expect(
        calls.where((call) => call.method == 'saveWidgetData').map(
              (call) => call.arguments,
            ),
        containsAll([
          {'id': 'upcoming_event_id', 'data': 'event-1'},
          {'id': 'upcoming_event_name', 'data': 'Warehouse Night'},
          {
            'id': 'upcoming_event_date',
            'data': '2026-07-01T20:00:00.000Z',
          },
          {'id': 'upcoming_event_venue', 'data': 'Main Room'},
        ]),
      );
      expect(calls.last.method, 'updateWidget');
      expect(calls.last.arguments, {
        'name': null,
        'android': CountdownWidgetService.androidWidgetName,
        'ios': CountdownWidgetService.iosWidgetName,
        'qualifiedAndroidName':
            CountdownWidgetService.qualifiedAndroidWidgetName,
      });
    });

    test('clears selected event data and refreshes native widgets', () async {
      await CountdownWidgetService.clearSelectedEvent();

      expect(calls.first.method, 'setAppGroupId');
      final saveCalls = calls.where((call) => call.method == 'saveWidgetData');
      expect(saveCalls, hasLength(4));
      for (final call in saveCalls) {
        expect((call.arguments as Map<Object?, Object?>)['data'], isNull);
      }
      expect(calls.last.method, 'updateWidget');
    });
  });
}
