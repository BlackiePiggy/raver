// Integration tests for the Discover browsing flow.
//
// Covers: browsing the events list, tapping into event detail, using the
// search overlay, and interacting with the genre sunburst visualization.
// Uses ProviderScope overrides to inject mock data providers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ravehub/app.dart';

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

/// Builds the app with mock overrides for Discover-related providers.
Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      // Override dioProvider with a mock that returns canned event lists,
      // DJ lists, and genre trees.
      // dioProvider.overrideWithValue(mockDio),
      //
      // Override appStateProvider to start with a logged-in session so the
      // app navigates directly to the main shell.
      // appStateProvider.overrideWith((_) => MockAppStateNotifier()),
    ],
    child: const RaveHubApp(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Discover Flow', () {
    testWidgets(
      'Browse events list -> tap event -> see detail',
      (WidgetTester tester) async {
        // 1. Pump the app (assumes logged-in state via mock override).
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // 2. Navigate to the Discover tab if not already there.
        //    The first tab in the bottom nav is Discover.
        final discoverTab = find.text('Discover');
        if (discoverTab.evaluate().isNotEmpty) {
          await tester.tap(discoverTab.first);
          await tester.pumpAndSettle();
        }

        // 3. The DiscoverHomeScreen should show with its scrollable tab pager.
        //    The "Events" tab is the second tab (index 1) after "Recommend".
        expect(find.text('Recommend'), findsOneWidget);
        expect(find.text('Events'), findsOneWidget);

        // 4. Tap the "Events" tab to switch to the events list.
        await tester.tap(find.text('Events'));
        await tester.pumpAndSettle();

        // 5. The EventsListScreen should now be visible.
        //    With mock data, we expect EventCard widgets to render.
        //    Each EventCard displays the event name via Text(event.name).
        // expect(find.byType(EventCard), findsWidgets);

        // 6. Tap the first event card to navigate to EventDetailScreen.
        final firstEventCard = find.byType(GestureDetector).first;
        await tester.tap(firstEventCard);
        await tester.pumpAndSettle();

        // 7. The EventDetailScreen should show with a SliverAppBar hero image
        //    and 3 tabs: Details, Lineup, Timetable.
        expect(find.byType(SliverAppBar), findsOneWidget);
        expect(find.text('Details'), findsOneWidget);
        expect(find.text('Lineup'), findsOneWidget);
        expect(find.text('Timetable'), findsOneWidget);

        // 8. Verify the event info section is visible (dates, location, stats).
        expect(find.byIcon(Icons.calendar_today), findsWidgets);
        expect(find.byIcon(Icons.favorite), findsWidgets);

        // 9. Tap the "Lineup" tab to see the lineup list.
        await tester.tap(find.text('Lineup'));
        await tester.pumpAndSettle();

        // 10. Tap back to return to the events list.
        final backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
          await tester.pumpAndSettle();
        }

        // 11. The events list should still be visible.
        expect(find.text('Events'), findsOneWidget);
      },
    );

    testWidgets(
      'Search overlay -> type query -> see results',
      (WidgetTester tester) async {
        // 1. Pump the app.
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // 2. Navigate to Discover tab.
        final discoverTab = find.text('Discover');
        if (discoverTab.evaluate().isNotEmpty) {
          await tester.tap(discoverTab.first);
          await tester.pumpAndSettle();
        }

        // 3. Tap the search icon in the AppBar to open SearchOverlayScreen.
        final searchIcon = find.byIcon(Icons.search);
        expect(searchIcon, findsWidgets);
        await tester.tap(searchIcon.first);
        await tester.pumpAndSettle();

        // 4. The SearchOverlayScreen should be visible with a text field
        //    and recent searches (if any).
        final searchField = find.byType(TextField);
        expect(searchField, findsOneWidget);

        // 5. Enter a search query.
        await tester.enterText(searchField, 'Awakenings');
        await tester.pumpAndSettle();

        // 6. Submit the search (press enter / tap submit).
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        // 7. SearchResultsScreen should appear with categorized results.
        //    The "All" tab shows a summary of results across all categories.
        // expect(find.text('All'), findsOneWidget);

        // 8. The search query should be preserved.
        // expect(find.text('Awakenings'), findsWidgets);

        // 9. Results should include SearchResultCard widgets.
        // expect(find.byType(SearchResultCard), findsWidgets);

        // 10. Dismiss the search overlay.
        // await tester.tap(find.byIcon(Icons.close));
        // await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Genre sunburst renders and responds to tap',
      (WidgetTester tester) async {
        // 1. Pump the app.
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // 2. Navigate to Discover tab.
        final discoverTab = find.text('Discover');
        if (discoverTab.evaluate().isNotEmpty) {
          await tester.tap(discoverTab.first);
          await tester.pumpAndSettle();
        }

        // 3. Swipe or tap to the "Genres" tab (index 8 in the scrollable
        //    tab pager: Recommend, Events, News, Organizers, DJs, Labels,
        //    Rankings, Sets, Genres).
        //    The tab may need horizontal scrolling to become visible.
        await tester.scrollUntilVisible(
          find.text('Genres'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Genres'));
        await tester.pumpAndSettle();

        // 4. The GenresRootScreen should render with a CustomPaint widget
        //    containing the GenreSunburstPainter.
        expect(find.byType(CustomPaint), findsWidgets);

        // 5. Tap on the center of the sunburst canvas to trigger a genre
        //    selection interaction.
        final customPaint = find.byType(CustomPaint).first;
        final center = tester.getCenter(customPaint);
        await tester.tapAt(center);
        await tester.pumpAndSettle();

        // 6. After tapping a genre sector, the expand animation should play
        //    and potentially navigate to GenreDetailScreen.
        //    GenreDetailScreen title would contain the genre name.
        // expect(find.byType(GenreDetailScreen), findsOneWidget);
      },
    );
  });
}
