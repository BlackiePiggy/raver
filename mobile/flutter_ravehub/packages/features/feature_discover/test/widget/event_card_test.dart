import 'package:feature_discover/src/events/presentation/widgets/event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

void main() {
  testWidgets('EventCard renders event-local time range and timezone', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RaverThemeData.darkTheme(),
        home: Scaffold(
          body: EventCard(
            event: const WebEvent(
              id: 'event-1',
              name: 'RaveHub Night',
              slug: 'ravehub-night',
              description: '',
              coverImageUrl: '',
              lineupImageUrl: '',
              eventType: 'warehouse',
              startDate: '2026-07-01T20:00:00+08:00',
              endDate: '2026-07-02T02:00:00+08:00',
              schedule: WebEventSchedule(
                mode: 'single',
                timezoneId: 'Asia/Shanghai',
                timezoneName: 'CST',
              ),
              favoriteCount: 12,
              checkinCount: 3,
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(
      find.text('2026-07-01 20:00 ~ 2026-07-02 02:00 · CST (Asia/Shanghai)'),
      findsOneWidget,
    );
  });

  testWidgets('EventCard exposes a share button callback', (tester) async {
    var shareTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: RaverThemeData.darkTheme(),
        home: Scaffold(
          body: EventCard(
            event: const WebEvent(
              id: 'event-1',
              name: 'RaveHub Night',
              slug: 'ravehub-night',
              description: '',
              coverImageUrl: '',
              lineupImageUrl: '',
              eventType: 'warehouse',
              startDate: '2026-07-01',
              endDate: '2026-07-01',
              favoriteCount: 12,
              checkinCount: 3,
            ),
            onTap: () {},
            onShare: () => shareTapCount++,
          ),
        ),
      ),
    );

    final shareButton = find.bySemanticsLabel('Share Event');
    expect(shareButton, findsOneWidget);

    await tester.tap(shareButton);
    await tester.pump();

    expect(shareTapCount, 1);
  });

  testWidgets('EventCard uses iOS row cover geometry and visual status badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RaverThemeData.darkTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: EventCard(
                event: const WebEvent(
                  id: 'event-1',
                  name: 'RaveHub Night',
                  slug: 'ravehub-night',
                  description: '',
                  coverImageUrl: '',
                  lineupImageUrl: '',
                  eventType: 'warehouse_party',
                  startDate: '2035-07-01T20:00:00+08:00',
                  endDate: '2035-07-02T02:00:00+08:00',
                  favoriteCount: 12,
                  checkinCount: 3,
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('JUL'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Warehouse'), findsOneWidget);

    final coverSize = tester.getSize(find.byType(RemoteCoverImage).first);
    expect(coverSize.width, iosEventRowCoverWidth);
    expect(coverSize.height, iosEventRowCoverHeight);
  });

  test('EventCard visual status resolves from event dates', () {
    final event = const WebEvent(
      id: 'event-1',
      name: 'RaveHub Night',
      slug: 'ravehub-night',
      description: '',
      coverImageUrl: '',
      lineupImageUrl: '',
      eventType: 'warehouse_party',
      startDate: '2035-07-01T20:00:00+08:00',
      endDate: '2035-07-02T02:00:00+08:00',
      favoriteCount: 12,
      checkinCount: 3,
    );

    expect(
      resolveEventCardVisualStatus(
        event,
        now: DateTime.parse('2035-06-30T20:00:00+08:00'),
      ),
      EventCardVisualStatus.upcoming,
    );
    expect(
      resolveEventCardVisualStatus(
        event,
        now: DateTime.parse('2035-07-01T21:00:00+08:00'),
      ),
      EventCardVisualStatus.ongoing,
    );
    expect(
      resolveEventCardVisualStatus(
        event,
        now: DateTime.parse('2035-07-03T21:00:00+08:00'),
      ),
      EventCardVisualStatus.ended,
    );
  });
}
