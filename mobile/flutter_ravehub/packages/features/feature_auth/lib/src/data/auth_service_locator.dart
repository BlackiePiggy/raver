import 'package:dio/dio.dart';
import 'package:raver_auth/raver_auth.dart';

import 'auth_api.dart';

/// Called after a successful registration to persist the selected home city.
typedef RegistrationLocationSaver = Future<void> Function(String location);

/// Called after any login-like auth response has persisted credentials.
typedef AuthenticatedSessionHandler = Future<void> Function(
  Map<String, dynamic> authPayload,
);

/// Singleton service locator for authentication dependencies.
///
/// Must be initialised (via [initialize]) before any auth feature is used,
/// typically at app startup.
class AuthServiceLocator {
  static AuthServiceLocator? _instance;
  static AuthServiceLocator get instance =>
      _instance ??= AuthServiceLocator._();
  AuthServiceLocator._();

  AuthApi? _api;
  SessionTokenStore? _tokenStore;
  RegistrationLocationSaver? _registrationLocationSaver;
  AuthenticatedSessionHandler? _authenticatedSessionHandler;

  /// Configures the locator with a [Dio] client and [SessionTokenStore].
  ///
  /// Call this once during app initialisation.
  void initialize({
    required Dio dio,
    required SessionTokenStore tokenStore,
    RegistrationLocationSaver? registrationLocationSaver,
    AuthenticatedSessionHandler? authenticatedSessionHandler,
  }) {
    _tokenStore = tokenStore;
    _api = AuthApi(dio);
    _registrationLocationSaver = registrationLocationSaver;
    _authenticatedSessionHandler = authenticatedSessionHandler;
  }

  /// The shared [AuthApi] instance.
  AuthApi get api => _api!;

  /// The shared [SessionTokenStore] instance.
  SessionTokenStore get tokenStore => _tokenStore!;

  /// Optional app-level callback for saving registration home-city location.
  RegistrationLocationSaver? get registrationLocationSaver =>
      _registrationLocationSaver;

  /// Optional app-level callback for syncing app session state after auth.
  AuthenticatedSessionHandler? get authenticatedSessionHandler =>
      _authenticatedSessionHandler;
}
