// Golden tests for RaveHub skeleton loading views.
//
// Run: flutter test --update-goldens  (to generate baseline PNGs)
// Run: flutter test                    (to compare against baseline)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: RaverThemeData.darkTheme(),
      home: Scaffold(body: child),
    );

void main() {
  group('Skeleton Golden', () {
    testWidgets('EventListSkeleton golden', (tester) async {
      await tester.pumpWidget(_wrap(
        const EventListSkeleton(itemCount: 2),
      ));
      await tester.pump();
      await expectLater(
        find.byType(EventListSkeleton),
        matchesGoldenFile('goldens/event_list_skeleton.png'),
      );
    });

    testWidgets('EventDetailSkeleton golden', (tester) async {
      await tester.pumpWidget(_wrap(
        const EventDetailSkeleton(),
      ));
      await tester.pump();
      await expectLater(
        find.byType(EventDetailSkeleton),
        matchesGoldenFile('goldens/event_detail_skeleton.png'),
      );
    });

    testWidgets('DJListSkeleton golden', (tester) async {
      await tester.pumpWidget(_wrap(
        const DJListSkeleton(itemCount: 3),
      ));
      await tester.pump();
      await expectLater(
        find.byType(DJListSkeleton),
        matchesGoldenFile('goldens/dj_list_skeleton.png'),
      );
    });
  });
}
