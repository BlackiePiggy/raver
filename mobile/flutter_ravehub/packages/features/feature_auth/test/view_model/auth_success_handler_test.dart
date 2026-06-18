import 'package:dio/dio.dart';
import 'package:feature_auth/src/data/auth_api.dart';
import 'package:feature_auth/src/data/auth_service_locator.dart';
import 'package:feature_auth/src/presentation/view_models/login_view_model.dart';
import 'package:feature_auth/src/presentation/view_models/register_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_auth/raver_auth.dart';

void main() {
  group('auth success handler', () {
    test('password login persists tokens and notifies app session handler',
        () async {
      final authPayload = _authPayload('login-user');
      final tokenStore = _RecordingTokenStore();
      final handledPayloads = <Map<String, dynamic>>[];
      AuthServiceLocator.instance.initialize(
        dio: Dio(),
        tokenStore: tokenStore,
        authenticatedSessionHandler: (payload) async {
          handledPayloads.add(payload);
        },
      );

      final notifier = LoginNotifier(
        api: _FakeAuthApi(loginPasswordPayload: authPayload),
        tokenStore: tokenStore,
      );
      addTearDown(notifier.dispose);

      notifier
        ..setMethod(LoginMethod.password)
        ..setUsername('tester')
        ..setPassword('secret-password')
        ..toggleTermsAgreement();

      final success = await notifier.login();

      expect(success, isTrue);
      expect(tokenStore.savedAccessToken, 'access-login-user');
      expect(tokenStore.savedRefreshToken, 'refresh-login-user');
      expect(tokenStore.savedExpiresIn, 7200);
      expect(handledPayloads, [authPayload]);
    });

    test('registration persists tokens and notifies app session handler',
        () async {
      final authPayload = _authPayload('registered-user');
      final tokenStore = _RecordingTokenStore();
      final handledPayloads = <Map<String, dynamic>>[];
      AuthServiceLocator.instance.initialize(
        dio: Dio(),
        tokenStore: tokenStore,
        authenticatedSessionHandler: (payload) async {
          handledPayloads.add(payload);
        },
      );

      final notifier = RegisterNotifier(
        api: _FakeAuthApi(registerPayload: authPayload),
        tokenStore: tokenStore,
      );
      addTearDown(notifier.dispose);

      notifier
        ..setDisplayName('Tester')
        ..setEmail('tester@example.com')
        ..setPassword('secret-password')
        ..setConfirmPassword('secret-password')
        ..toggleTermsAgreement();
      await _waitForDisplayNameCheck(notifier);

      final success = await notifier.register();

      expect(success, isTrue);
      expect(tokenStore.savedAccessToken, 'access-registered-user');
      expect(tokenStore.savedRefreshToken, 'refresh-registered-user');
      expect(tokenStore.savedExpiresIn, 7200);
      expect(handledPayloads, [authPayload]);
    });
  });
}

Map<String, dynamic> _authPayload(String userId) => {
      'accessToken': 'access-$userId',
      'refreshToken': 'refresh-$userId',
      'expiresIn': 7200,
      'user': {
        'id': userId,
        'username': userId,
        'displayName': 'Tester',
      },
    };

Future<void> _waitForDisplayNameCheck(RegisterNotifier notifier) async {
  for (var i = 0; i < 10; i += 1) {
    if (!notifier.state.isCheckingDisplayName) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

class _RecordingTokenStore extends SessionTokenStore {
  String? savedAccessToken;
  String? savedRefreshToken;
  int? savedExpiresIn;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    savedAccessToken = accessToken;
    savedRefreshToken = refreshToken;
    savedExpiresIn = expiresIn;
  }
}

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi({
    Map<String, dynamic>? loginPasswordPayload,
    Map<String, dynamic>? registerPayload,
  })  : _loginPasswordPayload = loginPasswordPayload,
        _registerPayload = registerPayload,
        super(Dio());

  final Map<String, dynamic>? _loginPasswordPayload;
  final Map<String, dynamic>? _registerPayload;

  @override
  Future<Map<String, dynamic>> loginWithPassword({
    required String username,
    required String password,
  }) async =>
      _loginPasswordPayload!;

  @override
  Future<bool> checkDisplayNameAvailability({
    required String displayName,
  }) async =>
      true;

  @override
  Future<Map<String, dynamic>> register({
    required String displayName,
    required String email,
    required String password,
    int? birthYear,
    String? regionCode,
  }) async =>
      _registerPayload!;
}
