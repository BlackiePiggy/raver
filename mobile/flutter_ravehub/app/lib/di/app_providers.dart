import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_auth/raver_auth.dart';
import 'package:raver_core/raver_core.dart';
import 'package:raver_network/raver_network.dart';
import 'package:ravehub/router/app_router.dart';
import 'package:ravehub/state/app_state_notifier.dart';

// ---------------------------------------------------------------------------
// Core infrastructure providers
// ---------------------------------------------------------------------------

/// Secure token storage backed by platform-native keychains.
final sessionTokenStoreProvider = Provider<SessionTokenStore>(
  (ref) => SessionTokenStore(),
  name: 'sessionTokenStore',
);

/// Deduplicates concurrent token-refresh requests.
final authRefreshGateProvider = Provider<AuthRefreshGate>(
  (ref) => AuthRefreshGate(),
  name: 'authRefreshGate',
);

// ---------------------------------------------------------------------------
// Networking
// ---------------------------------------------------------------------------

/// Fully configured [Dio] client produced by [DioClientFactory] with auth,
/// language, envelope unwrapping, and debug logging interceptors.
final dioProvider = Provider<Dio>((ref) {
  final tokenStore = ref.watch(sessionTokenStoreProvider);
  final refreshGate = ref.watch(authRefreshGateProvider);
  final appState = ref.watch(appStateProvider.notifier);

  return DioClientFactory.create(
    baseUrl: AppConfig.bffBaseUrl,
    tokenStore: tokenStore,
    refreshGate: refreshGate,
    languageProvider: () => appState.preferredLanguage.name,
    onSessionExpired: appState.expireSession,
  );
}, name: 'dio');

// ---------------------------------------------------------------------------
// Application state
// ---------------------------------------------------------------------------

/// The central app state notifier -- session, language, appearance, badges.
final appStateProvider = ChangeNotifierProvider<AppStateNotifier>(
  (ref) => AppStateNotifier(
    tokenStore: ref.watch(sessionTokenStoreProvider),
  ),
  name: 'appState',
);

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

/// The application's [GoRouter] instance with auth guards and deep-link
/// support.
final routerProvider = Provider<GoRouter>(
  (ref) => createRouter(ref, ref.watch(appStateProvider)),
  name: 'router',
);
