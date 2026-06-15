import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';

import 'package:feature_auth/src/presentation/login_screen.dart';
import 'package:feature_auth/src/presentation/view_models/login_view_model.dart';

/// Helper that wraps a widget with MaterialApp + RaverTheme + ProviderScope.
Widget _buildApp({
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: RaverThemeData.darkTheme(),
      home: const LoginScreen(),
    ),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('renders brand header with app name', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // The brand header should display the RaveHub app name.
      expect(find.text(RaverTypography.appName), findsOneWidget);
    });

    testWidgets('renders email/SMS method tabs by default', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Default view shows Email and SMS tab items.
      expect(find.text('Email Login'), findsOneWidget);
      expect(find.text('SMS Login'), findsOneWidget);
    });

    testWidgets('renders Log In button', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // There should be at least one "Log In" text (from the PrimaryButton).
      expect(find.text('Log In'), findsWidgets);
    });

    testWidgets('renders Register link at the bottom', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // The register link text should be present.
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('renders terms agreement checkbox', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // There should be a Checkbox for terms agreement.
      expect(find.byType(Checkbox), findsOneWidget);

      // The terms-related text should be present.
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });
  });
}
