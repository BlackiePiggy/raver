import 'dart:async';

import 'package:dio/dio.dart';
import 'package:raver_auth/raver_auth.dart';
import 'package:raver_core/raver_core.dart';

import 'service_error_mapper.dart';

/// Paths that must not carry an Authorization header.
const _publicPaths = <String>[
  '/v1/auth/login',
  '/v1/auth/register',
  '/v1/auth/refresh',
];

/// Called when the interceptor determines that the local session is no longer
/// valid and the app should return to the unauthenticated state.
typedef SessionExpiredCallback = FutureOr<void> Function(
    SessionExpirationReason reason);

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
    SessionExpiredCallback? onSessionExpired,
  })  : _tokenStore = tokenStore,
        _refreshGate = refreshGate,
        _dio = dio,
        _onSessionExpired = onSessionExpired;

  final SessionTokenStore _tokenStore;
  final AuthRefreshGate _refreshGate;
  final Dio _dio;
  final SessionExpiredCallback? _onSessionExpired;

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

    final explicitReason =
        NetworkServiceErrorMapper.sessionExpirationReasonFromPayload(
      response.data,
    );
    if (explicitReason != null) {
      await _expireSession(explicitReason);
      if (explicitReason == SessionExpirationReason.accountInactive) {
        return handler.reject(
          _serviceErrorException(err, const ServiceError.accountInactive()),
        );
      }
      return handler.reject(
        _serviceErrorException(
            err, ServiceError.sessionExpired(explicitReason)),
      );
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
        await _expireSession(SessionExpirationReason.expired);
        return handler.reject(
          _serviceErrorException(
            err,
            const ServiceError.sessionExpired(SessionExpirationReason.expired),
          ),
        );
      }

      // Retry the original request with the new token.
      final newToken = await _tokenStore.readAccessToken();
      final options = err.requestOptions;
      options.headers['Authorization'] = 'Bearer $newToken';

      final retryResponse = await _dio.fetch<dynamic>(options);
      return handler.resolve(retryResponse);
    } on ServiceError catch (error) {
      if (error is SessionExpiredError) {
        await _expireSession(error.reason);
      } else if (error is AccountInactiveError) {
        await _expireSession(SessionExpirationReason.accountInactive);
      }
      return handler.reject(_serviceErrorException(err, error));
    } catch (_) {
      await _expireSession(SessionExpirationReason.expired);
      return handler.reject(
        _serviceErrorException(
          err,
          const ServiceError.sessionExpired(SessionExpirationReason.expired),
        ),
      );
    }
  }

  Future<void> _expireSession(SessionExpirationReason reason) async {
    await _tokenStore.clearTokens();
    await _onSessionExpired?.call(reason);
  }

  DioException _serviceErrorException(DioException original, Object error) {
    return DioException(
      requestOptions: original.requestOptions,
      response: original.response,
      type: DioExceptionType.unknown,
      error: error,
    );
  }
}
