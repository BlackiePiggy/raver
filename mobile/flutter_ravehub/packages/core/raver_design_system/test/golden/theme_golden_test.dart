// Golden tests for RaveHub design system theme components.
//
// Run: flutter test --update-goldens  (to generate baseline PNGs)
// Run: flutter test                    (to compare against baseline)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';

Widget _wrap(Widget child, {bool dark = false}) => MaterialApp(
      theme: dark ? RaverThemeData.darkTheme() : RaverThemeData.lightTheme(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('GlassCard Golden', () {
    testWidgets('light theme', (tester) async {
      await tester.pumpWidget(_wrap(
        const GlassCard(
          child: SizedBox(
            width: 200,
            height: 100,
            child: Center(child: Text('Glass Card')),
          ),
        ),
      ));
      await expectLater(
        find.byType(GlassCard),
        matchesGoldenFile('goldens/glass_card_light.png'),
      );
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(_wrap(
        const GlassCard(
          child: SizedBox(
            width: 200,
            height: 100,
            child: Center(child: Text('Glass Card')),
          ),
        ),
        dark: true,
      ));
      await expectLater(
        find.byType(GlassCard),
        matchesGoldenFile('goldens/glass_card_dark.png'),
      );
    });
  });

  group('PrimaryButton Golden', () {
    testWidgets('enabled state', (tester) async {
      await tester.pumpWidget(_wrap(
        PrimaryButton(label: 'Get Started', onPressed: () {}),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PrimaryButton),
        matchesGoldenFile('goldens/primary_button_enabled.png'),
      );
    });

    testWidgets('loading state', (tester) async {
      await tester.pumpWidget(_wrap(
        PrimaryButton(label: 'Get Started', onPressed: () {}, isLoading: true),
      ));
      await tester.pump();
      await expectLater(
        find.byType(PrimaryButton),
        matchesGoldenFile('goldens/primary_button_loading.png'),
      );
    });

    testWidgets('disabled state', (tester) async {
      await tester.pumpWidget(_wrap(
        const PrimaryButton(label: 'Get Started', onPressed: null),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PrimaryButton),
        matchesGoldenFile('goldens/primary_button_disabled.png'),
      );
    });
  });
}
