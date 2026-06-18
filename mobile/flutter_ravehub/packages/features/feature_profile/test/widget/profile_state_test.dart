import 'package:dio/dio.dart';
import 'package:feature_profile/src/_shared/profile_service_locator.dart';
import 'package:feature_profile/src/follow_list/follow_list_screen.dart';
import 'package:feature_profile/src/profile_me/profile_me_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';

Widget _buildRoutedApp(Widget home) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      GoRoute(
        path: '/profile/settings',
        builder: (_, __) => const Scaffold(body: Text('settings-route')),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const Scaffold(body: Text('edit-route')),
      ),
      GoRoute(
        path: '/profile/follow-list/:type',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(path: '/profile/publishes', builder: (_, __) => const Scaffold()),
      GoRoute(
        path: '/profile/contributions',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(path: '/profile/quiz', builder: (_, __) => const Scaffold()),
      GoRoute(
        path: '/profile/personality',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(path: '/profile/saves', builder: (_, __) => const Scaffold()),
      GoRoute(
        path: '/profile/checkins',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(
        path: '/profile/tools/route',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(path: '/scan', builder: (_, __) => const Scaffold()),
      GoRoute(
        path: '/profile/virtual-assets',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(
        path: '/profile/tools/widgets',
        builder: (_, __) => const Scaffold(),
      ),
      GoRoute(path: '/users/:id', builder: (_, __) => const Scaffold()),
    ],
  );

  return MaterialApp.router(
    theme: RaverThemeData.darkTheme(),
    routerConfig: router,
  );
}

Dio _profileDio({required List<String> requests}) {
  return Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options.path);
          if (options.path == '/v1/users/me') {
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const {
                  'id': 'user-1',
                  'username': 'bass_runner',
                  'displayName': 'Bass Runner',
                  'bio': 'Warehouse regular',
                  'followerCount': 8,
                  'followingCount': 5,
                  'friendCount': 2,
                  'postCount': 0,
                },
              ),
            );
            return;
          }
          if (options.path == '/v1/users/me/posts' ||
              options.path == '/v1/users/me/saves' ||
              options.path == '/v1/users/me/following') {
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
}

void main() {
  tearDown(() {
    ProfileServiceLocator.configureDio(
      Dio(BaseOptions(baseUrl: 'https://api.ravehub.top')),
    );
  });

  group('Profile state surfaces', () {
    testWidgets('profile home success state remains pull-to-refreshable', (
      tester,
    ) async {
      final requests = <String>[];
      ProfileServiceLocator.configureDio(_profileDio(requests: requests));

      await tester.pumpWidget(_buildRoutedApp(const ProfileMeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(requests, contains('/v1/users/me'));
      expect(requests, contains('/v1/users/me/posts'));
      expect(find.byType(RefreshIndicator), findsOneWidget);
      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(scrollView.physics, isA<AlwaysScrollableScrollPhysics>());
    });

    testWidgets('follow list empty state remains pull-to-refreshable', (
      tester,
    ) async {
      final requests = <String>[];
      ProfileServiceLocator.configureDio(_profileDio(requests: requests));

      await tester.pumpWidget(
        _buildRoutedApp(const FollowListScreen(listType: 'following')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(requests, contains('/v1/users/me/following'));
      expect(find.byType(EmptyStateView), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scrollView.physics, isA<AlwaysScrollableScrollPhysics>());
    });

    testWidgets('profile settings entry point opens the settings route', (
      tester,
    ) async {
      final requests = <String>[];
      ProfileServiceLocator.configureDio(_profileDio(requests: requests));

      await tester.pumpWidget(_buildRoutedApp(const ProfileMeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('settings-route'), findsOneWidget);
    });

    testWidgets('profile edit entry point opens the edit route', (
      tester,
    ) async {
      final requests = <String>[];
      ProfileServiceLocator.configureDio(_profileDio(requests: requests));

      await tester.pumpWidget(_buildRoutedApp(const ProfileMeScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      expect(find.text('edit-route'), findsOneWidget);
    });
  });
}
