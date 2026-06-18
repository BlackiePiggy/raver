import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_auth/raver_auth.dart';

import '../../data/auth_api.dart';
import '../../data/auth_error_message.dart';
import '../../data/auth_service_locator.dart';

/// The method the user has selected for login.
enum LoginMethod {
  /// Login with email + verification code.
  email,

  /// Login with SMS phone number + verification code.
  sms,

  /// Login with username + password.
  password,
}

/// Immutable snapshot of the login form state.
class LoginState {
  /// Creates a [LoginState].
  const LoginState({
    this.method = LoginMethod.email,
    this.isLoading = false,
    this.errorMessage,
    this.codeSent = false,
    this.cooldownSeconds = 0,
    this.email = '',
    this.phone = '',
    this.countryCode = '+86',
    this.verificationCode = '',
    this.username = '',
    this.password = '',
    this.agreedToTerms = false,
    this.showPasswordLogin = false,
  });

  /// The currently selected login method.
  final LoginMethod method;

  /// Whether a network request is in flight.
  final bool isLoading;

  /// An error message to display, if any.
  final String? errorMessage;

  /// Whether a verification code has been sent successfully.
  final bool codeSent;

  /// Remaining seconds before the user can request a new code.
  final int cooldownSeconds;

  /// Email address input.
  final String email;

  /// Phone number input (digits only, no country code).
  final String phone;

  /// Selected country code (e.g. "+86", "+1", "+81").
  final String countryCode;

  /// Verification code input (for email/SMS methods).
  final String verificationCode;

  /// Username input (for password method).
  final String username;

  /// Password input (for password method).
  final String password;

  /// Whether the user has agreed to terms & privacy policy.
  final bool agreedToTerms;

  /// Whether the password-login section is expanded.
  final bool showPasswordLogin;

  /// Whether the "Send Code" button should be enabled.
  bool get canSendCode {
    if (isLoading || cooldownSeconds > 0) return false;
    return switch (method) {
      LoginMethod.email => _isValidEmail(email),
      LoginMethod.sms => phone.length >= 6,
      LoginMethod.password => false,
    };
  }

  /// Whether the login button should be enabled.
  bool get canLogin {
    if (isLoading || !agreedToTerms) return false;
    return switch (method) {
      LoginMethod.email => _isValidEmail(email) && verificationCode.length == 6,
      LoginMethod.sms => phone.length >= 6 && verificationCode.length == 6,
      LoginMethod.password => username.isNotEmpty && password.length >= 6,
    };
  }

  /// Returns a copy with the given fields replaced.
  LoginState copyWith({
    LoginMethod? method,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? codeSent,
    int? cooldownSeconds,
    String? email,
    String? phone,
    String? countryCode,
    String? verificationCode,
    String? username,
    String? password,
    bool? agreedToTerms,
    bool? showPasswordLogin,
  }) {
    return LoginState(
      method: method ?? this.method,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      codeSent: codeSent ?? this.codeSent,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      countryCode: countryCode ?? this.countryCode,
      verificationCode: verificationCode ?? this.verificationCode,
      username: username ?? this.username,
      password: password ?? this.password,
      agreedToTerms: agreedToTerms ?? this.agreedToTerms,
      showPasswordLogin: showPasswordLogin ?? this.showPasswordLogin,
    );
  }

  static bool _isValidEmail(String value) {
    if (value.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }
}

/// Notifier that manages the login form lifecycle.
///
/// Handles switching between login methods, sending verification codes with
/// a cooldown timer, and performing the actual login request.
class LoginNotifier extends StateNotifier<LoginState> {
  /// Creates a [LoginNotifier].
  ///
  /// If [api] and [tokenStore] are not provided, they are resolved from
  /// [AuthServiceLocator]. If the locator has not been initialised, a
  /// fallback [AuthApi] backed by a fresh [Dio] instance pointed at the
  /// production BFF is created.
  LoginNotifier({AuthApi? api, SessionTokenStore? tokenStore})
      : _api = api ?? _resolveApi(),
        _tokenStore = tokenStore ?? _resolveTokenStore(),
        super(const LoginState());

  final AuthApi _api;
  final SessionTokenStore _tokenStore;

  Timer? _cooldownTimer;

  static AuthApi _resolveApi() {
    try {
      return AuthServiceLocator.instance.api;
    } catch (_) {
      return AuthApi(
        Dio(BaseOptions(
          baseUrl: 'https://api.ravehub.top',
          headers: {'Content-Type': 'application/json'},
        )),
      );
    }
  }

  static SessionTokenStore _resolveTokenStore() {
    try {
      return AuthServiceLocator.instance.tokenStore;
    } catch (_) {
      return SessionTokenStore();
    }
  }

  // ---------------------------------------------------------------------------
  // Method switching
  // ---------------------------------------------------------------------------

  /// Switch between email / SMS login tabs.
  void setMethod(LoginMethod method) {
    state = state.copyWith(
      method: method,
      clearError: true,
      codeSent: false,
      verificationCode: '',
      cooldownSeconds: 0,
    );
    _cancelCooldown();
  }

  /// Toggle visibility of the password-login section.
  void togglePasswordLogin() {
    if (state.showPasswordLogin) {
      // Collapse: go back to current tab method
      state = state.copyWith(
        showPasswordLogin: false,
        method: LoginMethod.email,
        clearError: true,
      );
    } else {
      state = state.copyWith(
        showPasswordLogin: true,
        method: LoginMethod.password,
        clearError: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Field updates
  // ---------------------------------------------------------------------------

  /// Update the email field.
  void setEmail(String value) =>
      state = state.copyWith(email: value, clearError: true);

  /// Update the phone field.
  void setPhone(String value) =>
      state = state.copyWith(phone: value, clearError: true);

  /// Update the selected country code.
  void setCountryCode(String value) =>
      state = state.copyWith(countryCode: value);

  /// Update the verification code field.
  void setVerificationCode(String value) =>
      state = state.copyWith(verificationCode: value, clearError: true);

  /// Update the username field.
  void setUsername(String value) =>
      state = state.copyWith(username: value, clearError: true);

  /// Update the password field.
  void setPassword(String value) =>
      state = state.copyWith(password: value, clearError: true);

  /// Toggle the terms agreement checkbox.
  void toggleTermsAgreement() =>
      state = state.copyWith(agreedToTerms: !state.agreedToTerms);

  /// Set a user-visible error message.
  void setError(String message) =>
      state = state.copyWith(errorMessage: message);

  /// Clear the current user-visible error message.
  void clearError() => state = state.copyWith(clearError: true);

  // ---------------------------------------------------------------------------
  // Send verification code
  // ---------------------------------------------------------------------------

  /// Sends a verification code via email or SMS.
  ///
  /// Starts the server-provided cooldown on success.
  Future<void> sendCode() async {
    if (!state.canSendCode) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      late final int cooldownSeconds;
      switch (state.method) {
        case LoginMethod.email:
          cooldownSeconds = await _api.sendEmailCode(email: state.email);
        case LoginMethod.sms:
          cooldownSeconds = await _api.sendSmsCode(
            phone: state.phone,
            countryCode: state.countryCode,
          );
        case LoginMethod.password:
          cooldownSeconds = 0;
      }

      state = state.copyWith(
        isLoading: false,
        codeSent: true,
        cooldownSeconds: cooldownSeconds,
      );
      _startCooldown();
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: authUserFacingError(e),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------------------

  /// Performs the login with the current method and field values.
  ///
  /// Returns `true` on success so the caller can navigate.
  Future<bool> login() async {
    if (!state.canLogin) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      Map<String, dynamic> result;

      switch (state.method) {
        case LoginMethod.email:
          result = await _api.loginWithEmail(
            email: state.email,
            code: state.verificationCode,
          );
        case LoginMethod.sms:
          result = await _api.loginWithSms(
            phone: state.phone,
            countryCode: state.countryCode,
            code: state.verificationCode,
          );
        case LoginMethod.password:
          result = await _api.loginWithPassword(
            username: state.username,
            password: state.password,
          );
      }

      // Persist tokens.
      final accessToken = result['accessToken'] as String;
      final refreshToken = result['refreshToken'] as String;
      final expiresIn = result['expiresIn'] as int? ?? 3600;
      await _tokenStore.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn,
      );
      await AuthServiceLocator.instance.authenticatedSessionHandler
          ?.call(result);

      state = state.copyWith(isLoading: false);
      return true;
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: authUserFacingError(e),
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Cooldown timer
  // ---------------------------------------------------------------------------

  void _startCooldown() {
    _cancelCooldown();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = state.cooldownSeconds - 1;
      if (remaining <= 0) {
        _cancelCooldown();
        state = state.copyWith(cooldownSeconds: 0);
      } else {
        state = state.copyWith(cooldownSeconds: remaining);
      }
    });
  }

  void _cancelCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
  }

  @override
  void dispose() {
    _cancelCooldown();
    super.dispose();
  }
}

/// Riverpod provider for [LoginNotifier].
final loginProvider =
    StateNotifierProvider.autoDispose<LoginNotifier, LoginState>(
  (ref) => LoginNotifier(),
);
