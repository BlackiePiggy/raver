import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:raver_auth/raver_auth.dart';

import 'auth_interceptor.dart';
import 'bff_envelope_interceptor.dart';
import 'language_interceptor.dart';
import 'logging_interceptor.dart';

/// Factory for creating a fully configured [Dio] instance with the standard
/// RaveHub interceptor stack.
///
/// The interceptors are applied in the following order:
///  1. [AuthInterceptor] -- injects bearer token, handles 401 refresh.
///  2. [LanguageInterceptor] -- sets `Accept-Language` header.
///  3. [BffEnvelopeInterceptor] -- unwraps the BFF response envelope.
///  4. [LoggingInterceptor] -- debug-only request/response logging.
class DioClientFactory {
  /// Creates and returns a [Dio] instance configured for the RaveHub BFF.
  ///
  /// Parameters:
  ///  * [baseUrl] -- the root URL of the BFF API (e.g. `https://api.ravehub.io`).
  ///  * [tokenStore] -- secure storage for OAuth tokens.
  ///  * [refreshGate] -- deduplicates concurrent token-refresh calls.
  ///  * [languageProvider] -- returns the current locale string.
  static Dio create({
    required String baseUrl,
    required SessionTokenStore tokenStore,
    required AuthRefreshGate refreshGate,
    required String Function() languageProvider,
    SessionExpiredCallback? onSessionExpired,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.addAll([
      AuthInterceptor(
        tokenStore: tokenStore,
        refreshGate: refreshGate,
        dio: dio,
        onSessionExpired: onSessionExpired,
      ),
      LanguageInterceptor(languageProvider: languageProvider),
      BffEnvelopeInterceptor(),
      if (kDebugMode) LoggingInterceptor(),
    ]);

    return dio;
  }
}
