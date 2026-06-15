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
  Future<void> sendEmailCode({required String email}) async {
    await _dio.post<void>(
      '/v1/auth/sms/send',
      data: {'email': email},
    );
  }

  /// Sends an SMS verification code to the given phone number.
  Future<void> sendSmsCode({
    required String phone,
    required String countryCode,
  }) async {
    await _dio.post<void>(
      '/v1/auth/sms/send',
      data: {'phone': phone, 'countryCode': countryCode},
    );
  }

  /// Registers a new user account.
  ///
  /// Returns the full response body containing `accessToken`, `refreshToken`,
  /// and `user`.
  Future<Map<String, dynamic>> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/register',
      data: {
        'displayName': displayName,
        'email': email,
        'password': password,
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
}
