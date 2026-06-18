import 'package:feature_circle/feature_circle.dart';
import 'package:feature_discover/feature_discover.dart' hide dioProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ravehub/app.dart';
import 'package:ravehub/di/app_providers.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Public live flows', () {
    testWidgets('Discover public tabs render against live services', (
      tester,
    ) async {
      final container = await _pumpLiveApp(tester);

      expect(container.read(appStateProvider).isLoggedIn, isFalse);
      expect(find.text('Discover'), findsWidgets);
      expect(find.text('Picks'), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);

      await tester.tap(find.text('Events'));
      await _pumpForNetwork(tester);

      expect(find.text('Events'), findsOneWidget);
      expect(find.byType(Scrollable), findsWidgets);
      _expectNoFrameworkException(tester);
    });

    testWidgets('Circle public tabs render against live services', (
      tester,
    ) async {
      await _pumpLiveApp(tester);

      await tester.tap(find.text('Circle').last);
      await _pumpForNetwork(tester);

      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Squads'), findsOneWidget);
      expect(find.text('ID'), findsOneWidget);
      expect(find.text('Ratings'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);

      await tester.tap(find.text('Squads'));
      await _pumpForNetwork(tester);
      expect(find.text('Sign in to view squads'), findsOneWidget);

      await tester.tap(find.text('ID'));
      await _pumpForNetwork(tester);
      expect(find.text('ID'), findsOneWidget);

      await tester.tap(find.text('Ratings'));
      await _pumpForNetwork(tester);
      expect(find.text('Ratings'), findsOneWidget);
      _expectNoFrameworkException(tester);
    });
  });
}

Future<ProviderContainer> _pumpLiveApp(WidgetTester tester) async {
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

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const RaveHubApp(),
    ),
  );
  await _pumpForNetwork(tester);
  return container;
}

Future<void> _pumpForNetwork(WidgetTester tester) async {
  for (var i = 0; i < 8; i += 1) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void _expectNoFrameworkException(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull);
}
