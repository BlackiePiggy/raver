import 'package:dio/dio.dart';

/// API client for all authentication endpoints.
///
/// Wraps Dio calls to the BFF auth endpoints for login, registration,
/// verification codes, token refresh, and logout.
class AuthApi {
  AuthApi(this._dio);
  final Dio _dio;

  /// Logs in with an email address and verification code.
  ///
  /// Returns the full response body containing `accessToken`, `refreshToken`,
  /// and `user`.
  Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String code,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/login/email',
      data: {'email': email, 'code': code},
    );
    return response.data!;
  }

  /// Logs in with a phone number and SMS verification code.
  Future<Map<String, dynamic>> loginWithSms({
    required String phone,
    required String countryCode,
    required String code,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/login/sms',
      data: {'phone': phone, 'countryCode': countryCode, 'code': code},
    );
    return response.data!;
  }

  /// Logs in with a username and password.
  Future<Map<String, dynamic>> loginWithPassword({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/login/password',
      data: {'username': username, 'password': password},
    );
    return response.data!;
  }

  /// Sends a verification code to the given email address.
  ///
  /// Returns the server-provided cooldown duration in seconds.
  Future<int> sendEmailCode({
    required String email,
    String scene = 'login',
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/auth/email/send',
      data: {'email': email, 'scene': scene},
    );
    return _authCodeCooldownSeconds(response.data);
  }

  /// Sends an SMS verification code to the given phone number.
  ///
  /// Returns the server-provided cooldown duration in seconds.
  Future<int> sendSmsCode({
    required String phone,
    required String countryCode,
    String scene = 'login',
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/auth/sms/send',
      data: {'phone': _normalizedPhone(phone, countryCode), 'scene': scene},
    );
    return _authCodeCooldownSeconds(response.data);
  }

  /// Checks whether a display name can be used during registration.
  Future<bool> checkDisplayNameAvailability({
    required String displayName,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/auth/display-name/check',
      queryParameters: {'displayName': displayName},
    );
    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        return data['available'] as bool? ?? false;
      }
      return payload['available'] as bool? ?? false;
    }
    return false;
  }

  /// Registers a new user account.
  ///
  /// Returns the full response body containing `accessToken`, `refreshToken`,
  /// and `user`.
  Future<Map<String, dynamic>> register({
    required String displayName,
    required String email,
    required String password,
    int? birthYear,
    String? regionCode,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/register',
      data: {
        'displayName': displayName,
        'email': email,
        'password': password,
        if (birthYear != null) 'birthYear': birthYear,
        if (regionCode != null) 'regionCode': regionCode,
      },
    );
    return response.data!;
  }

  /// Refreshes the access token using a valid refresh token.
  Future<Map<String, dynamic>> refreshToken({
    required String refreshToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return response.data!;
  }

  /// Logs out the current session by invalidating the refresh token.
  Future<void> logout({required String refreshToken}) async {
    await _dio.post<void>(
      '/v1/auth/logout',
      data: {'refreshToken': refreshToken},
    );
  }

  /// Initiates a password reset flow for the given email address.
  Future<void> resetPassword({required String email}) async {
    await _dio.post<void>(
      '/v1/auth/password/reset',
      data: {'email': email},
    );
  }

  /// Verifies a Firebase ID token with the backend.
  ///
  /// Returns the full response body containing `accessToken`, `refreshToken`,
  /// and `user`.
  Future<Map<String, dynamic>> verifyFirebaseToken({
    required String firebaseIdToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/firebase/verify',
      data: {'firebaseIdToken': firebaseIdToken},
    );
    return response.data!;
  }

  static int _authCodeCooldownSeconds(dynamic payload) {
    final expiresInSeconds = switch (payload) {
      {'expiresInSeconds': final int seconds} => seconds,
      {'data': {'expiresInSeconds': final int seconds}} => seconds,
      _ => throw const FormatException(
          'Auth code response did not include expiresInSeconds',
        ),
    };
    return expiresInSeconds.clamp(1, 120);
  }

  static String _normalizedPhone(String phone, String countryCode) {
    final trimmedPhone = phone.trim();
    final trimmedCountryCode = countryCode.trim();
    if (trimmedPhone.startsWith('+') || trimmedCountryCode.isEmpty) {
      return trimmedPhone;
    }
    return '$trimmedCountryCode$trimmedPhone';
  }
}
