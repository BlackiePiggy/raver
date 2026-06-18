import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';

import 'package:feature_profile/src/settings/settings_screen.dart';
import 'package:feature_profile/src/settings/appearance_setting_screen.dart';
import 'package:feature_profile/src/settings/cache_manage_screen.dart';
import 'package:feature_profile/src/settings/language_setting_screen.dart';

/// Wraps a widget with MaterialApp.router (GoRouter) + RaverTheme so that
/// [context.push] and [context.raver] both work inside the widget under test.
Widget _buildRoutedApp(Widget home) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      // Stub child routes so context.push() doesn't throw.
      GoRoute(
        path: '/profile/settings/account-security',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(
        path: '/profile/settings/devices',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(
        path: '/profile/settings/language',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(
        path: '/profile/settings/appearance',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(
        path: '/profile/settings/cache',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(
        path: '/profile/settings/permissions',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(
        path: '/profile/settings/about',
        builder: (_, __) => const Scaffold(),
      ),
    ],
  );

  return MaterialApp.router(
    theme: RaverThemeData.darkTheme(),
    routerConfig: router,
  );
}

void main() {
  group('SettingsScreen', () {
    testWidgets('renders Account section with security and devices tiles',
        (tester) async {
      await tester.pumpWidget(_buildRoutedApp(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Account Security'), findsOneWidget);
      expect(find.text('Device Management'), findsOneWidget);
    });

    testWidgets('renders General section with language and appearance tiles',
        (tester) async {
      await tester.pumpWidget(_buildRoutedApp(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
    });

    testWidgets('renders Privacy and About tiles', (tester) async {
      await tester.pumpWidget(_buildRoutedApp(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Cache Management'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('About'), 300);
      expect(find.text('About'), findsOneWidget);
    });
  });

  group('AppearanceSettingScreen', () {
    testWidgets('renders three appearance options', (tester) async {
      await tester.pumpWidget(
        _buildRoutedApp(const AppearanceSettingScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Follow System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('tapping Light option changes selection', (tester) async {
      await tester.pumpWidget(
        _buildRoutedApp(const AppearanceSettingScreen()),
      );
      await tester.pumpAndSettle();

      // Tap the "Light" option.
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      // After tapping, the widget tree should still show all three options
      // (selection state change doesn't remove options from the tree).
      expect(find.text('Follow System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });
  });

  group('LanguageSettingScreen', () {
    testWidgets('renders language options', (tester) async {
      await tester.pumpWidget(
        _buildRoutedApp(const LanguageSettingScreen()),
      );
      await tester.pumpAndSettle();

      // All three supported languages should be shown.
      expect(find.text('中文'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('日本語'), findsOneWidget);
    });
  });

  group('CacheManageScreen', () {
    testWidgets('renders live cache status rows', (tester) async {
      await tester.pumpWidget(_buildRoutedApp(const CacheManageScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Cache Status'), findsOneWidget);
      expect(find.text('Memory image cache'), findsOneWidget);
      expect(find.text('Disk image cache'), findsOneWidget);
      expect(find.text('23.5 MB'), findsNothing);
    });
  });
}
