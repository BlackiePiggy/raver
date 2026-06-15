import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:feature_inbox/src/presentation/notification_settings_screen.dart';

Widget _buildApp(Widget child) {
  return MaterialApp(
    theme: RaverThemeData.darkTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('LoadPhaseBuilder — Inbox notifications', () {
    testWidgets('shows loading indicator when fetching unread counts',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          LoadPhaseBuilder<NotificationUnreadCount>(
            phase: const LoadPhase.loading(),
            onSuccess: (_) => const SizedBox.shrink(),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows unread count data when loaded', (tester) async {
      const unread = NotificationUnreadCount(
        community: 3,
        followedEvents: 0,
        followedDJs: 1,
        followedBrands: 0,
      );

      await tester.pumpWidget(
        _buildApp(
          LoadPhaseBuilder<NotificationUnreadCount>(
            phase: const LoadPhase.success(unread),
            onSuccess: (counts) => Column(
              children: [
                Text('Community: ${counts.community}'),
                Text('DJs: ${counts.followedDJs}'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Community: 3'), findsOneWidget);
      expect(find.text('DJs: 1'), findsOneWidget);
    });

    testWidgets('shows empty state when no notifications', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          LoadPhaseBuilder<NotificationUnreadCount>(
            phase: const LoadPhase.empty(),
            onSuccess: (_) => const SizedBox.shrink(),
            onEmpty: () => const EmptyStateView(
              icon: Icons.notifications_none_outlined,
              title: 'All Caught Up',
              subtitle: 'No new notifications',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.text('All Caught Up'), findsOneWidget);
    });

    testWidgets('shows default error widget when onFailure not provided',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          LoadPhaseBuilder<NotificationUnreadCount>(
            phase: const LoadPhase.failure('Service unavailable'),
            onSuccess: (_) => const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default fallback renders the error message as text.
      expect(find.text('Service unavailable'), findsOneWidget);
    });
  });

  group('NotificationSettingsScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders all notification toggle switches', (tester) async {
      await tester.pumpWidget(
        _buildApp(const NotificationSettingsScreen()),
      );
      await tester.pump(); // allow initState async to start
      await tester.pump(const Duration(milliseconds: 50)); // SharedPrefs loads

      // All 7 toggles should be on screen.
      expect(find.byType(SwitchListTile), findsNWidgets(7));
    });

    testWidgets('toggles switch state on tap', (tester) async {
      await tester.pumpWidget(
        _buildApp(const NotificationSettingsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final switchesBefore = tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      final firstValue = switchesBefore.first.value;

      // Tap the first switch to toggle it.
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final switchesAfter = tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchesAfter.first.value, !firstValue);
    });
  });
}
