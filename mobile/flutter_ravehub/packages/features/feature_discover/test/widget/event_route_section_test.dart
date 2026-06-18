import 'package:feature_discover/src/events/presentation/widgets/event_route_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

void main() {
  testWidgets(
      'EventRouteSection navigates with address when coordinates absent',
      (tester) async {
    String? capturedDestination;

    await tester.pumpWidget(
      MaterialApp(
        theme: RaverThemeData.darkTheme(),
        home: Scaffold(
          body: EventRouteSection(
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
              location: WebEventManualLocation(
                name: 'Dada Shanghai',
                address: '115 Xingfu Road',
                city: 'Shanghai',
                country: 'CN',
              ),
              favoriteCount: 0,
              checkinCount: 0,
            ),
            routeLauncher: (
                {required location, required destinationQuery}) async {
              capturedDestination = destinationQuery;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.navigation_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.navigation_outlined));
    await tester.pump();

    expect(capturedDestination, 'Dada Shanghai, 115 Xingfu Road, Shanghai, CN');
  });
}
