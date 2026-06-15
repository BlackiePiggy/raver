import 'package:dio/dio.dart';
import 'package:raver_auth/raver_auth.dart';
import 'package:raver_core/raver_core.dart';

/// Paths that must not carry an Authorization header.
const _publicPaths = <String>[
  '/v1/auth/login',
  '/v1/auth/register',
  '/v1/auth/refresh',
];

/// Dio interceptor that attaches an OAuth bearer token to every request and
/// transparently refreshes expired tokens on 401 responses.
///
/// Ported from the iOS `AuthenticatedRequestRunner` and `AuthInterceptor`.
///
/// Behaviour:
///  * Reads the current access token from [SessionTokenStore] and adds it as
///    an `Authorization: Bearer` header.
///  * Adds `Cache-Control: no-cache` and `Pragma: no-cache` headers.
///  * Skips authentication entirely for public paths (login, register, refresh).
///  * On a 401 response, uses [AuthRefreshGate] to coordinate a single token
///    refresh across all concurrent callers, then retries the original request.
///  * If the refresh itself fails, throws a [ServiceError.sessionExpired].
class AuthInterceptor extends Interceptor {
  /// Creates an [AuthInterceptor].
  AuthInterceptor({
    required SessionTokenStore tokenStore,
    required AuthRefreshGate refreshGate,
    required Dio dio,
  })  : _tokenStore = tokenStore,
        _refreshGate = refreshGate,
        _dio = dio;

  final SessionTokenStore _tokenStore;
  final AuthRefreshGate _refreshGate;
  final Dio _dio;

  // ------------------------------------------------------------------
  // Request phase
  // ------------------------------------------------------------------

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Always add cache-busting headers.
    options.headers['Cache-Control'] = 'no-cache';
    options.headers['Pragma'] = 'no-cache';

    // Skip auth for public endpoints.
    final path = options.path;
    if (_publicPaths.any((p) => path.contains(p))) {
      return handler.next(options);
    }

    // Attach the bearer token if available.
    final token = await _tokenStore.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  // ------------------------------------------------------------------
  // Error phase – token refresh on 401
  // ------------------------------------------------------------------

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;

    // Only handle 401 Unauthorized.
    if (response == null || response.statusCode != 401) {
      return handler.next(err);
    }

    // Don't attempt to refresh for public paths.
    final path = err.requestOptions.path;
    if (_publicPaths.any((p) => path.contains(p))) {
      return handler.next(err);
    }

    try {
      final refreshed = await _refreshGate.refreshIfNeeded(() async {
        final refreshToken = await _tokenStore.readRefreshToken();
        if (refreshToken == null) return false;

        try {
          final refreshResponse = await _dio.post<Map<String, dynamic>>(
            '/v1/auth/refresh',
            data: {'refreshToken': refreshToken},
          );

          final body = refreshResponse.data;
          if (body == null) return false;

          await _tokenStore.saveTokens(
            accessToken: body['accessToken'] as String,
            refreshToken: body['refreshToken'] as String,
            expiresIn: body['expiresIn'] as int,
          );

          return true;
        } catch (_) {
          return false;
        }
      });

      if (!refreshed) {
        throw const ServiceError.sessionExpired(SessionExpirationReason.expired);
      }

      // Retry the original request with the new token.
      final newToken = await _tokenStore.readAccessToken();
      final options = err.requestOptions;
      options.headers['Authorization'] = 'Bearer $newToken';

      final retryResponse = await _dio.fetch<dynamic>(options);
      return handler.resolve(retryResponse);
    } on ServiceError {
      rethrow;
    } catch (_) {
      throw const ServiceError.sessionExpired(SessionExpirationReason.expired);
    }
  }
}
