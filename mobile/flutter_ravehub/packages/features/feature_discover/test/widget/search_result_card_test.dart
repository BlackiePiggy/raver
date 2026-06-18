import 'package:feature_discover/feature_discover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

Widget _buildApp(Widget child) {
  return MaterialApp(
    theme: RaverThemeData.darkTheme(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('SearchResultCard', () {
    testWidgets('renders live result content and exposes button semantics',
        (tester) async {
      final semantics = tester.ensureSemantics();

      var tapped = false;

      await tester.pumpWidget(
        _buildApp(
          SearchResultCard(
            item: const GlobalSearchItem(
              id: 'event-1',
              type: GlobalSearchItemType.event,
              entityId: 'event-1',
              title: 'Basement Night',
              subtitle: 'Berlin',
            ),
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Event'), findsOneWidget);
      expect(find.text('Basement Night'), findsOneWidget);
      expect(find.text('Berlin'), findsOneWidget);
      final node = tester.getSemantics(
        find.byKey(const ValueKey('search_result_card_semantics')),
      );
      expect(node.label, 'Event, Basement Night, Berlin');
      expect(node.flagsCollection.isButton, isTrue);
      semantics.dispose();

      await tester.tap(find.byType(SearchResultCard));
      expect(tapped, isTrue);
    });
  });
}
