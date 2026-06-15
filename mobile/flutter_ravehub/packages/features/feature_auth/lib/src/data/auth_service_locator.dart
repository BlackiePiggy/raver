import 'package:dio/dio.dart';
import 'package:raver_auth/raver_auth.dart';

import 'auth_api.dart';

/// Singleton service locator for authentication dependencies.
///
/// Must be initialised (via [initialize]) before any auth feature is used,
/// typically at app startup.
class AuthServiceLocator {
  static AuthServiceLocator? _instance;
  static AuthServiceLocator get instance =>
      _instance ??= AuthServiceLocator._();
  AuthServiceLocator._();

  Dio? _dio;
  AuthApi? _api;
  SessionTokenStore? _tokenStore;

  /// Configures the locator with a [Dio] client and [SessionTokenStore].
  ///
  /// Call this once during app initialisation.
  void initialize({
    required Dio dio,
    required SessionTokenStore tokenStore,
  }) {
    _dio = dio;
    _tokenStore = tokenStore;
    _api = AuthApi(dio);
  }

  /// The shared [AuthApi] instance.
  AuthApi get api => _api!;

  /// The shared [SessionTokenStore] instance.
  SessionTokenStore get tokenStore => _tokenStore!;
}
