import 'package:dio/dio.dart';
import 'package:feature_inbox/src/data/inbox_service_locator.dart';
import 'package:feature_inbox/src/presentation/followed_events_inbox_screen.dart';
import 'package:feature_inbox/src/presentation/inbox_home_screen.dart';
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

  group('InboxHomeScreen', () {
    tearDown(() {
      InboxServiceLocator.configureUnreadCountSync(null);
    });

    testWidgets('syncs live unread counts for the app tab badge', (
      tester,
    ) async {
      NotificationUnreadCount? syncedCounts;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/v1/notification-center/unread-count') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'community': 2,
                      'followedEvents': 3,
                      'followedDJs': 5,
                      'followedBrands': 7,
                    },
                  ),
                );
                return;
              }
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );

      InboxServiceLocator.configureDio(dio);
      InboxServiceLocator.configureUnreadCountSync((counts) {
        syncedCounts = counts;
      });

      await tester.pumpWidget(_buildApp(const InboxHomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(syncedCounts, isNotNull);
      expect(syncedCounts!.community, 2);
      expect(syncedCounts!.followedEvents, 3);
      expect(syncedCounts!.followedDJs, 5);
      expect(syncedCounts!.followedBrands, 7);
      expect(find.text('Community'), findsOneWidget);
      expect(find.text('Followed Events'), findsOneWidget);
      expect(find.text('Followed DJs'), findsOneWidget);
      expect(find.text('Followed Brands'), findsOneWidget);
      expect(find.text('Content Reviews'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.physics, isA<AlwaysScrollableScrollPhysics>());
    });

    testWidgets('followed events empty state remains refreshable', (
      tester,
    ) async {
      var followedEventsRequests = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path ==
                  '/v1/notification-center/followed-events/items') {
                followedEventsRequests += 1;
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'items': <Map<String, dynamic>>[],
                      'pagination': {
                        'page': 1,
                        'limit': 20,
                        'total': 0,
                        'totalPages': 1,
                      },
                    },
                  ),
                );
                return;
              }
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );

      InboxServiceLocator.configureDio(dio);

      await tester.pumpWidget(_buildApp(const FollowedEventsInboxScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(followedEventsRequests, 1);
      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scrollView.physics, isA<AlwaysScrollableScrollPhysics>());
    });
  });
}
