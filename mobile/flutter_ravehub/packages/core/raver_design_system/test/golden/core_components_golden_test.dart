import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';

void main() {
  group('Core components golden', () {
    testWidgets('empty and error states', (tester) async {
      await _setSurface(tester, const Size(420, 760));

      await tester.pumpWidget(
        _wrap(
          RepaintBoundary(
            key: const ValueKey('states'),
            child: Column(
              children: [
                SizedBox(
                  height: 360,
                  child: EmptyStateView(
                    icon: Icons.music_note_outlined,
                    title: 'No sets yet',
                    subtitle: 'Follow DJs or labels to build your feed.',
                    actionLabel: 'Explore',
                    onAction: () {},
                  ),
                ),
                const Divider(height: 1),
                SizedBox(
                  height: 360,
                  child: ErrorStateView(
                    title: 'Could not load',
                    description: 'Check your connection and try again.',
                    onRetry: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await expectLater(
        find.byKey(const ValueKey('states')),
        matchesGoldenFile('goldens/core_states.png'),
      );
    });

    testWidgets('segmented control and floating tab bar', (tester) async {
      await _setSurface(tester, const Size(430, 260));

      await tester.pumpWidget(
        _wrap(
          RepaintBoundary(
            key: const ValueKey('controls'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 340,
                    child: RaverSegmentedControl(
                      segments: const ['Recommended', 'Following', 'Latest'],
                      selectedIndex: 1,
                      onChanged: (_) {},
                    ),
                  ),
                  SizedBox(
                    height: 120,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: RaverFloatingTabBar(
                        selectedIndex: 2,
                        inboxBadgeCount: 12,
                        onTap: (_) {},
                        onSearchTap: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const ValueKey('controls')),
        matchesGoldenFile('goldens/core_controls.png'),
      );
    });
  });
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _wrap(Widget child) => MaterialApp(
      theme: RaverThemeData.darkTheme(),
      home: Scaffold(
        backgroundColor: RaverThemeData.dark().background,
        body: Center(child: child),
      ),
    );
