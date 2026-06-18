import 'package:feature_discover/feature_discover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';

void main() {
  group('SearchOverlayScreen', () {
    setUp(() {
      DiscoverServiceLocator.configureRecentSearchStore(
        _FakeRecentSearchStore(),
      );
    });

    testWidgets('keeps overlay full-screen while keyboard is visible', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RaverThemeData.darkTheme(),
          home: const MediaQuery(
            data: MediaQueryData(
              viewInsets: EdgeInsets.only(bottom: 320),
            ),
            child: SearchOverlayScreen(),
          ),
        ),
      );
      await tester.pump();

      final root = find.byKey(const ValueKey('global_search_overlay_root'));

      expect(root, findsOneWidget);
      expect(tester.getSize(root), tester.getSize(find.byType(MaterialApp)));
    });

    testWidgets('renders iOS-style blurred overlay chrome', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RaverThemeData.darkTheme(),
          home: const SearchOverlayScreen(),
        ),
      );
      await tester.pump();

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('Global Search'), findsOneWidget);
      expect(find.text('Search across RaveHub'), findsOneWidget);
    });
  });
}

class _FakeRecentSearchStore extends RecentSearchStore {
  @override
  List<String> get queries => const [];

  @override
  Future<void> initialize() async {
    notifyListeners();
  }
}
