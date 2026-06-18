import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ravehub/di/app_providers.dart';
import 'package:ravehub/router/route_guards.dart';
import 'package:raver_models/raver_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('auth redirect guard', () {
    testWidgets(
        'redirects unauthenticated protected routes to login with returnTo',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = _testRouter(
        appState: container.read(appStateProvider.notifier),
        initialLocation: '/profile',
      );

      await tester.pumpWidget(_GuardApp(container: container, router: router));
      await tester.pumpAndSettle();

      expect(find.text('login'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/login?returnTo=%2Fprofile',
      );
    });

    testWidgets(
        'preserves search query when redirecting unauthenticated search route',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = _testRouter(
        appState: container.read(appStateProvider.notifier),
        initialLocation: '/search?q=techno',
      );

      await tester.pumpWidget(_GuardApp(container: container, router: router));
      await tester.pumpAndSettle();

      expect(find.text('login'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/login?returnTo=%2Fsearch%3Fq%3Dtechno',
      );
    });

    testWidgets('redirects authenticated login returnTo back to target route',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final appState = container.read(appStateProvider.notifier)
        ..setSession(
          const Session(
            token: 'access-token',
            refreshToken: 'refresh-token',
            accessTokenExpiresIn: 3600,
            user: UserSummary(
              id: 'user-1',
              username: 'tester',
              displayName: 'Tester',
            ),
          ),
        );
      final router = _testRouter(
        appState: appState,
        initialLocation: '/login?returnTo=%2Fprofile',
      );

      await tester.pumpWidget(_GuardApp(container: container, router: router));
      await tester.pumpAndSettle();

      expect(find.text('profile'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.toString(), '/profile');
    });

    testWidgets('returns authenticated login returnTo back to search query',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final appState = container.read(appStateProvider.notifier)
        ..setSession(
          const Session(
            token: 'access-token',
            refreshToken: 'refresh-token',
            accessTokenExpiresIn: 3600,
            user: UserSummary(
              id: 'user-1',
              username: 'tester',
              displayName: 'Tester',
            ),
          ),
        );
      final router = _testRouter(
        appState: appState,
        initialLocation: '/login?returnTo=%2Fsearch%3Fq%3Dtechno',
      );

      await tester.pumpWidget(_GuardApp(container: container, router: router));
      await tester.pumpAndSettle();

      expect(find.text('search'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/search?q=techno',
      );
    });
  });
}

GoRouter _testRouter({
  required ChangeNotifier appState,
  required String initialLocation,
}) =>
    GoRouter(
      initialLocation: initialLocation,
      refreshListenable: appState,
      redirect: authRedirectGuard,
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, __) => const Text('login'),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const Text('profile'),
        ),
        GoRoute(
          path: '/search',
          builder: (_, __) => const Text('search'),
        ),
        GoRoute(
          path: '/discover',
          builder: (_, __) => const Text('discover'),
        ),
      ],
    );

class _GuardApp extends StatelessWidget {
  const _GuardApp({required this.container, required this.router});

  final ProviderContainer container;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    );
  }
}
