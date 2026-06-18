import 'package:feature_discover/src/events/presentation/widgets/event_schedule_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

void main() {
  testWidgets('EventScheduleSection filters multi-day slots by selected day',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RaverThemeData.darkTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: EventScheduleSection(
              event: _event(),
              timetable: const [
                WebEventLineupSlot(
                  id: 'slot-1',
                  stageName: 'Main',
                  startTime: '2026-07-01T23:00:00+08:00',
                  endTime: '2026-07-02T02:00:00+08:00',
                  artistName: 'Opening DJ',
                  djId: 'dj-1',
                ),
                WebEventLineupSlot(
                  id: 'slot-2',
                  stageName: 'Main',
                  startTime: '2026-07-02T21:00:00+08:00',
                  endTime: '2026-07-02T22:00:00+08:00',
                  artistName: 'Second Day DJ',
                  djId: 'dj-2',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Day 1 · 07-01'), findsOneWidget);
    expect(find.text('Day 2 · 07-02'), findsOneWidget);
    expect(find.text('Opening DJ'), findsOneWidget);
    expect(find.text('23:00 - Next day 02:00'), findsOneWidget);
    expect(find.text('Second Day DJ'), findsNothing);

    await tester.tap(find.text('Day 2 · 07-02'));
    await tester.pumpAndSettle();

    expect(find.text('Opening DJ'), findsNothing);
    expect(find.text('Second Day DJ'), findsOneWidget);
    expect(find.text('21:00 - 22:00'), findsOneWidget);
  });

  testWidgets('EventScheduleSection preserves structured week day labels',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RaverThemeData.darkTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: EventScheduleSection(
              event: _event(
                weeks: const [
                  WebEventWeek(
                    startDate: '2026-07-01',
                    endDate: '2026-07-02',
                    days: [
                      WebEventDay(
                        id: 'w1d1',
                        date: '2026-07-01',
                        label: 'Opening',
                      ),
                    ],
                  ),
                  WebEventWeek(
                    startDate: '2026-07-08',
                    endDate: '2026-07-09',
                    days: [
                      WebEventDay(
                        id: 'w2d1',
                        date: '2026-07-08',
                        label: 'Closing',
                      ),
                    ],
                  ),
                ],
              ),
              timetable: const [
                WebEventLineupSlot(
                  id: 'slot-1',
                  stageName: 'Main',
                  startTime: '2026-07-08T22:00:00+08:00',
                  endTime: '2026-07-08T23:00:00+08:00',
                  artistName: 'Closing DJ',
                  djId: 'dj-1',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Week 1 · Opening'), findsOneWidget);
    expect(find.text('Week 2 · Closing'), findsOneWidget);

    await tester.tap(find.text('Week 2 · Closing'));
    await tester.pumpAndSettle();

    expect(find.text('Closing DJ'), findsOneWidget);
  });
}

WebEvent _event({List<WebEventWeek>? weeks}) {
  return WebEvent(
    id: 'event-1',
    name: 'RaveHub Night',
    slug: 'ravehub-night',
    description: '',
    coverImageUrl: '',
    lineupImageUrl: '',
    eventType: 'warehouse',
    startDate: '2026-07-01T20:00:00+08:00',
    endDate: '2026-07-02T04:00:00+08:00',
    weeks: weeks,
    favoriteCount: 0,
    checkinCount: 0,
  );
}
