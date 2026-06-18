import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';

void main() {
  testWidgets(
      'center search action is a semantic button and does not switch tabs', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var selectedTab = -1;
    var searchTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: RaverThemeData.darkTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RaverFloatingTabBar(
              selectedIndex: 0,
              inboxBadgeCount: 3,
              onTap: (index) => selectedTab = index,
              onSearchTap: () => searchTapCount++,
            ),
          ),
        ),
      ),
    );

    final searchButton = find.byKey(
      const ValueKey('raver_floating_tab_bar_search_button'),
    );
    final node = tester.getSemantics(searchButton);

    expect(node.label, 'Search');
    // ignore: deprecated_member_use
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);

    await tester.tap(searchButton);
    await tester.pump();

    expect(searchTapCount, 1);
    expect(selectedTab, -1);
    semantics.dispose();
  });

  testWidgets('hides while keyboard is visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RaverThemeData.darkTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            viewInsets: EdgeInsets.only(bottom: 320),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: RaverFloatingTabBar(
              selectedIndex: 0,
              onTap: (_) {},
              onSearchTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('raver_floating_tab_bar_search_button')),
      findsNothing,
    );
  });
}
