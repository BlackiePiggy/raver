import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_auth/raver_auth.dart';
import 'package:raver_core/raver_core.dart';
import 'package:raver_network/raver_network.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthInterceptor', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('expires session and clears tokens when refresh fails after 401',
        () async {
      final tokenStore = SessionTokenStore();
      await tokenStore.saveTokens(
        accessToken: 'expired-access',
        refreshToken: 'expired-refresh',
        expiresIn: 60,
      );

      SessionExpirationReason? expiredReason;
      final requests = <String>[];
      final authHeaders = <String?>[];
      final dio = DioClientFactory.create(
        baseUrl: 'https://api.ravehub.top',
        tokenStore: tokenStore,
        refreshGate: AuthRefreshGate(),
        languageProvider: () => 'en',
        onSessionExpired: (reason) => expiredReason = reason,
      );
      dio.httpClientAdapter = _FailingRefreshAdapter(
        onRequest: (options) {
          requests.add('${options.method} ${options.path}');
          authHeaders.add(options.headers['Authorization'] as String?);
        },
      );

      final error = await _captureDioError(
        () => dio.get<dynamic>('/v1/protected/profile'),
      );

      expect(requests, [
        'GET /v1/protected/profile',
        'POST /v1/auth/refresh',
      ]);
      expect(error.error, isA<SessionExpiredError>());
      expect(authHeaders.first, 'Bearer expired-access');
      expect(authHeaders.last, isNull);
      expect(expiredReason, SessionExpirationReason.expired);
      expect(await tokenStore.hasTokens(), isFalse);
    });
  });
}

Future<DioException> _captureDioError(
  Future<Response<dynamic>> Function() request,
) async {
  try {
    await request().timeout(const Duration(seconds: 5));
  } on DioException catch (error) {
    return error;
  }
  fail('Expected request to fail with a DioException.');
}

class _FailingRefreshAdapter implements HttpClientAdapter {
  _FailingRefreshAdapter({required this.onRequest});

  final void Function(RequestOptions options) onRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest(options);
    if (options.path == '/v1/protected/profile') {
      return ResponseBody.fromString(
        '{"message":"Unauthorized"}',
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.path == '/v1/auth/refresh') {
      return ResponseBody.fromString(
        '{"code":"AUTH_REFRESH_TOKEN_INVALID_OR_EXPIRED"}',
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString('Not found', 404);
  }

  @override
  void close({bool force = false}) {}
}
