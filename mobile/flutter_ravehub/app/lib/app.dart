import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:ravehub/di/app_providers.dart';
import 'package:ravehub/state/app_state_notifier.dart';

/// The root widget for the RaveHub application.
///
/// Uses [MaterialApp.router] with [GoRouter] for declarative navigation and
/// applies the raver design system theme based on the user's appearance
/// preference.
class RaveHubApp extends ConsumerWidget {
  /// Creates the [RaveHubApp].
  const RaveHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appState = ref.watch(appStateProvider);

    return MaterialApp.router(
      // ---- Navigation ----------------------------------------------------
      routerConfig: router,

      // ---- Appearance ----------------------------------------------------
      title: 'RaveHub',
      debugShowCheckedModeBanner: false,
      themeMode: _resolveThemeMode(appState.appearance),
      theme: RaverThemeData.lightTheme(),
      darkTheme: RaverThemeData.darkTheme(),

      // ---- Localisation --------------------------------------------------
      // The raver_i18n package handles translations at the call site via
      // lt() / ll(), so we do not use Flutter's built-in localisation
      // delegates here.
    );
  }

  // --------------------------------------------------------------------------
  // Theme helpers
  // --------------------------------------------------------------------------

  /// Converts [AppAppearance] to a Flutter [ThemeMode].
  static ThemeMode _resolveThemeMode(AppAppearance appearance) {
    switch (appearance) {
      case AppAppearance.system:
        return ThemeMode.system;
      case AppAppearance.light:
        return ThemeMode.light;
      case AppAppearance.dark:
        return ThemeMode.dark;
    }
  }
}
