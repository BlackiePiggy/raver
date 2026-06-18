import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:feature_discover/feature_discover.dart' as discover;
import 'package:ravehub/app.dart';
import 'package:ravehub/bootstrap.dart';
import 'package:ravehub/di/app_providers.dart' as app_di;
import 'package:ravehub/lifecycle/app_lifecycle_sync_controller.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Warm up raster cache for common hero animations and lock orientation.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Increase the in-memory image cache to reduce network re-fetches for
  // cover images, avatars, and other frequently displayed assets.
  PaintingBinding.instance.imageCache.maximumSize = 150;
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      100 * 1024 * 1024; // 100 MB

  await _initializeFirebaseIfConfigured();

  // Create the Riverpod container early so bootstrap can read/write providers.
  final container = ProviderContainer(
    overrides: [
      discover.dioProvider.overrideWith(
        (ref) => ref.watch(app_di.dioProvider),
      ),
      discover.organizerApiProvider.overrideWith(
        (ref) => discover.OrganizerApi(ref.watch(app_di.dioProvider)),
      ),
      discover.labelApiProvider.overrideWith(
        (ref) => discover.LabelApi(ref.watch(app_di.dioProvider)),
      ),
      discover.rankingApiProvider.overrideWith(
        (ref) => discover.RankingApi(ref.watch(app_di.dioProvider)),
      ),
      discover.genreApiProvider.overrideWith(
        (ref) => discover.GenreApi(ref.watch(app_di.dioProvider)),
      ),
    ],
  );

  // Run app initialisation (session restore, preferences, push permissions).
  await AppBootstrap.run(container);
  AppLifecycleSyncController(container: container).attach();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RaveHubApp(),
    ),
  );
  FlutterNativeSplash.remove();

  // Set up push notification deep link handling after the router is available.
  AppBootstrap.setupPushNotificationDeepLinks(container);
}

Future<void> _initializeFirebaseIfConfigured() async {
  try {
    await Firebase.initializeApp();
    developer.log('Firebase initialized.', name: 'Bootstrap');
  } catch (error) {
    developer.log(
      'Firebase initialization skipped: $error',
      name: 'Bootstrap',
      level: 800,
    );
  }
}
