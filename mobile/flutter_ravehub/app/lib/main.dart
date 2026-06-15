import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ravehub/app.dart';
import 'package:ravehub/bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Warm up raster cache for common hero animations and lock orientation.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Increase the in-memory image cache to reduce network re-fetches for
  // cover images, avatars, and other frequently displayed assets.
  PaintingBinding.instance.imageCache.maximumSize = 150;
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      100 * 1024 * 1024; // 100 MB

  // TODO: Pre-warm flutter_native_splash once the package is added.
  // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // TODO: Uncomment when Firebase config files are added to the project.
  // await Firebase.initializeApp();

  // Create the Riverpod container early so bootstrap can read/write providers.
  final container = ProviderContainer();

  // Run app initialisation (session restore, preferences, push permissions).
  await AppBootstrap.run(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RaveHubApp(),
    ),
  );

  // Set up push notification deep link handling after the router is available.
  AppBootstrap.setupPushNotificationDeepLinks(container);
}
