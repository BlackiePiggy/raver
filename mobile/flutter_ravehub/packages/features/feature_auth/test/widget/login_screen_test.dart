import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';

import 'package:feature_auth/src/presentation/login_screen.dart';

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
    testWidgets('renders iOS center brand asset', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('login_center_brand_asset')),
          findsOneWidget);
    });

    testWidgets('renders manual sign-in entry by default', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Email or Account Sign In'), findsOneWidget);
      expect(find.text('Third-party login is coming soon.'), findsNothing);
      expect(find.byIcon(Icons.apple), findsNothing);
    });

    testWidgets('renders Create New Account link', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Create New Account'), findsOneWidget);
    });

    testWidgets('renders terms agreement checkbox', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });
  });
}
