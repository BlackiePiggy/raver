import 'package:feature_circle/feature_circle.dart';
import 'package:feature_discover/feature_discover.dart' hide dioProvider;
import 'package:feature_inbox/feature_inbox.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ravehub/app.dart';
import 'package:ravehub/di/app_providers.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Clean launch shell smoke', () {
    testWidgets('clean unauthenticated launch can visit every root tab entry', (
      tester,
    ) async {
      final container = await _pumpCleanLiveApp(tester);

      expect(container.read(appStateProvider).isLoggedIn, isFalse);
      expect(find.text('Discover'), findsWidgets);
      expect(find.text('Picks'), findsOneWidget);
      _expectNoFrameworkException(tester);

      await tester.tap(find.text('Circle').last);
      await _pumpForShell(tester);
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Squads'), findsOneWidget);
      _expectNoFrameworkException(tester);

      await tester.tap(find.text('Inbox').last);
      await _pumpForShell(tester);
      expect(find.text('Email or Account Sign In'), findsOneWidget);
      _expectNoFrameworkException(tester);

      await tester.tap(find.text('Preview'));
      await _pumpForShell(tester);
      expect(find.text('Discover'), findsWidgets);
      _expectNoFrameworkException(tester);

      await tester.tap(find.text('Profile').last);
      await _pumpForShell(tester);
      expect(find.text('Email or Account Sign In'), findsOneWidget);
      _expectNoFrameworkException(tester);
    });
  });
}

Future<ProviderContainer> _pumpCleanLiveApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  AppLanguagePreference.instance
    ..language = AppLanguage.en
    ..systemLanguageOverride = AppLanguage.en;

  final container = ProviderContainer();
  addTearDown(() {
    AppLanguagePreference.instance
      ..language = AppLanguage.system
      ..systemLanguageOverride = null;
    container.dispose();
  });

  final dio = container.read(dioProvider);
  final appState = container.read(appStateProvider.notifier);
  DiscoverServiceLocator.configureDio(dio);
  DiscoverServiceLocator.configureCurrentUserIdProvider(
    () => appState.session?.user.id,
  );
  CircleServiceLocator.configureDio(dio);
  CircleServiceLocator.configureCurrentUserIdProvider(
    () => appState.session?.user.id,
  );
  InboxServiceLocator.configureDio(dio);
  InboxServiceLocator.configureUnreadCountSync(
    (counts) => appState.updateUnreadCounts(
      community: counts.community,
      events: counts.followedEvents,
      djs: counts.followedDJs,
      brands: counts.followedBrands,
    ),
  );
  ProfileServiceLocator.configureDio(
    dio,
    tokenStore: container.read(sessionTokenStoreProvider),
    onAccountSessionCleared: appState.clearSession,
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const RaveHubApp(),
    ),
  );
  await _pumpForShell(tester);
  return container;
}

Future<void> _pumpForShell(WidgetTester tester) async {
  for (var i = 0; i < 8; i += 1) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void _expectNoFrameworkException(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull);
}
