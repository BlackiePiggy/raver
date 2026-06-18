import 'package:feature_circle/feature_circle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';

Widget _buildApp(Widget child) {
  return MaterialApp(
    theme: RaverThemeData.darkTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('SquadHallScreen', () {
    testWidgets('shows sign-in gate for unauthenticated users', (
      tester,
    ) async {
      CircleServiceLocator.configureCurrentUserIdProvider(() => null);

      await tester.pumpWidget(_buildApp(const SquadHallScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to view squads'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Failed to Load'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
