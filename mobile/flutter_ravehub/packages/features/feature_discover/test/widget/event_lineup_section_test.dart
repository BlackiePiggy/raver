import 'package:feature_discover/src/events/presentation/widgets/event_lineup_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

void main() {
  testWidgets('EventLineupSection renders B2B members as tappable chips',
      (tester) async {
    final tapped = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: RaverThemeData.darkTheme(),
        home: Scaffold(
          body: EventLineupSection(
            artists: const [
              WebEventLineupArtist(
                id: 'artist-1',
                name: 'Back 2 Back',
                djId: '',
                avatarUrl: '',
                isB2B: true,
                members: [
                  WebEventLineupArtistMember(
                    name: 'Member One',
                    djId: 'dj-1',
                  ),
                  WebEventLineupArtistMember(
                    name: 'Member Two',
                    djId: 'dj-2',
                  ),
                ],
              ),
            ],
            onDjTap: tapped.add,
          ),
        ),
      ),
    );

    expect(find.text('Back 2 Back'), findsWidgets);
    expect(find.text('B2B'), findsOneWidget);
    expect(find.text('Member One'), findsOneWidget);
    expect(find.text('Member Two'), findsOneWidget);

    await tester.tap(find.text('Member Two'));
    await tester.pump();

    expect(tapped, ['dj-2']);
  });

  testWidgets('EventLineupSection toggles between popularity and A-Z sorting',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RaverThemeData.darkTheme(),
        home: Scaffold(
          body: EventLineupSection(
            artists: const [
              WebEventLineupArtist(
                id: 'artist-1',
                name: 'Zed DJ',
                djId: 'dj-z',
                avatarUrl: '',
                isB2B: false,
              ),
              WebEventLineupArtist(
                id: 'artist-2',
                name: 'Alpha DJ',
                djId: 'dj-a',
                avatarUrl: '',
                isB2B: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Hot'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'A-Z'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'A-Z'));
    await tester.pumpAndSettle();

    expect(find.text('A-Z'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'By popularity'), findsOneWidget);
  });
}
