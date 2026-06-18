import 'dart:io';
import 'dart:ui' as ui;

import 'package:feature_circle/feature_circle.dart';
import 'package:feature_discover/feature_discover.dart' hide dioProvider;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ravehub/app.dart';
import 'package:ravehub/di/app_providers.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshot parity capture', () {
    testWidgets('captures public Login, Discover, Sets, and Circle surfaces', (
      tester,
    ) async {
      await _configureViewport(tester);
      await _pumpLiveApp(tester);

      await tester.tap(find.text('Profile').last);
      await _pumpForNetwork(tester);
      expect(find.text('Email or Account Sign In'), findsOneWidget);
      await _captureScreenshot('login_initial');

      await tester.tap(find.text('Preview'));
      await _pumpForNetwork(tester);
      expect(find.text('Discover'), findsWidgets);
      expect(find.text('Picks'), findsOneWidget);
      await _captureScreenshot('discover_picks');

      await tester.tap(find.text('Events'));
      await _pumpForNetwork(tester);
      expect(find.text('Events'), findsOneWidget);
      await _captureScreenshot('discover_events');

      await _tapScrollableTab(tester, 'Sets');
      await _pumpForNetwork(tester);
      expect(find.text('Sets'), findsWidgets);
      await _captureScreenshot('discover_sets');

      await tester.tap(find.text('Circle').last);
      await _pumpForNetwork(tester);
      expect(find.text('Feed'), findsOneWidget);
      await _captureScreenshot('circle_feed');

      await tester.tap(find.text('Squads'));
      await _pumpForNetwork(tester);
      expect(find.text('Sign in to view squads'), findsOneWidget);
      await _captureScreenshot('circle_squads_login');

      await tester.tap(find.text('ID'));
      await _pumpForNetwork(tester);
      expect(find.text('ID'), findsOneWidget);
      await _captureScreenshot('circle_id');

      await tester.tap(find.text('Ratings'));
      await _pumpForNetwork(tester);
      expect(find.text('Ratings'), findsOneWidget);
      await _captureScreenshot('circle_ratings');

      _expectNoFrameworkException(tester);
    });
  });
}

final _screenshotSurfaceKey = GlobalKey();

Future<void> _configureViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1179, 2556);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
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
    RepaintBoundary(
      key: _screenshotSurfaceKey,
      child: UncontrolledProviderScope(
        container: container,
        child: const RaveHubApp(),
      ),
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

Future<void> _tapScrollableTab(WidgetTester tester, String label) async {
  final labelFinder = find.text(label);

  for (var i = 0; i < 8; i += 1) {
    final hitTestable = labelFinder.hitTestable();
    if (hitTestable.evaluate().isNotEmpty) {
      await tester.tap(hitTestable.first);
      return;
    }

    await tester.drag(find.byType(TabBar), const Offset(-220, 0));
    await tester.pump(const Duration(milliseconds: 350));
  }

  await tester.ensureVisible(labelFinder);
  await tester.tap(labelFinder);
}

Future<void> _captureScreenshot(String name) async {
  final boundary = _screenshotSurfaceKey.currentContext!.findRenderObject()!
      as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 3);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();
  final outputDirectory = await _createScreenshotDirectory();
  final file = File('${outputDirectory.path}/$name.png');
  await file.writeAsBytes(bytes, flush: true);
  debugPrint('RAVEHUB_SCREENSHOT_WRITTEN=${file.path}');
}

const _screenshotDirectory = String.fromEnvironment(
  'RAVEHUB_SCREENSHOT_DIR',
  defaultValue: '',
);

Future<Directory> _createScreenshotDirectory() async {
  final configuredPath = _screenshotDirectory.trim();
  if (configuredPath.isNotEmpty) {
    final configuredDirectory = Directory(configuredPath).absolute;
    try {
      await configuredDirectory.create(recursive: true);
      return configuredDirectory;
    } on FileSystemException catch (error) {
      debugPrint(
        'RAVEHUB_SCREENSHOT_DIR_FALLBACK=${configuredDirectory.path}: $error',
      );
    }
  }

  final fallbackDirectory = Directory(
    '${Directory.systemTemp.path}/ravehub_screenshots',
  ).absolute;
  await fallbackDirectory.create(recursive: true);
  return fallbackDirectory;
}

void _expectNoFrameworkException(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull);
}
