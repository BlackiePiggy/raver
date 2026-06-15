import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_auth/raver_auth.dart';

import '../../data/auth_api.dart';
import '../../data/auth_service_locator.dart';

/// Immutable snapshot of the registration form state.
class RegisterState {
  /// Creates a [RegisterState].
  const RegisterState({
    this.isLoading = false,
    this.errorMessage,
    this.displayName = '',
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.agreedToTerms = false,
    this.isDisplayNameAvailable = true,
    this.isCheckingDisplayName = false,
    this.passwordVisible = false,
    this.confirmPasswordVisible = false,
    this.registrationSuccess = false,
  });

  /// Whether a network request is in flight.
  final bool isLoading;

  /// An error message to display, if any.
  final String? errorMessage;

  /// Display name input.
  final String displayName;

  /// Email address input.
  final String email;

  /// Password input.
  final String password;

  /// Confirm-password input.
  final String confirmPassword;

  /// Whether the user has agreed to terms & privacy policy.
  final bool agreedToTerms;

  /// Result of the display-name availability check.
  final bool isDisplayNameAvailable;

  /// Whether a display-name check is currently in progress.
  final bool isCheckingDisplayName;

  /// Whether the password field text is visible.
  final bool passwordVisible;

  /// Whether the confirm-password field text is visible.
  final bool confirmPasswordVisible;

  /// Set to `true` after a successful registration.
  final bool registrationSuccess;

  // ---------------------------------------------------------------------------
  // Validation helpers
  // ---------------------------------------------------------------------------

  /// Whether the display name meets minimum requirements.
  bool get isDisplayNameValid => displayName.length >= 2;

  /// Whether the email looks valid.
  bool get isEmailValid {
    if (email.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  /// Whether the password meets strength requirements.
  bool get isPasswordValid => password.length >= 8;

  /// Whether confirm password matches.
  bool get passwordsMatch =>
      password.isNotEmpty && password == confirmPassword;

  /// Overall form validity.
  bool get canRegister =>
      !isLoading &&
      isDisplayNameValid &&
      isDisplayNameAvailable &&
      !isCheckingDisplayName &&
      isEmailValid &&
      isPasswordValid &&
      passwordsMatch &&
      agreedToTerms;

  /// Password strength label.
  String? get passwordStrengthHint {
    if (password.isEmpty) return null;
    if (password.length < 8) return 'Too short (min 8 characters)';
    final hasUpper = password.contains(RegExp('[A-Z]'));
    final hasDigit = password.contains(RegExp('[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    final score = [hasUpper, hasDigit, hasSpecial].where((b) => b).length;
    return switch (score) {
      0 => 'Weak',
      1 => 'Fair',
      2 => 'Good',
      _ => 'Strong',
    };
  }

  /// Returns a copy with the given fields replaced.
  RegisterState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? displayName,
    String? email,
    String? password,
    String? confirmPassword,
    bool? agreedToTerms,
    bool? isDisplayNameAvailable,
    bool? isCheckingDisplayName,
    bool? passwordVisible,
    bool? confirmPasswordVisible,
    bool? registrationSuccess,
  }) {
    return RegisterState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      agreedToTerms: agreedToTerms ?? this.agreedToTerms,
      isDisplayNameAvailable:
          isDisplayNameAvailable ?? this.isDisplayNameAvailable,
      isCheckingDisplayName:
          isCheckingDisplayName ?? this.isCheckingDisplayName,
      passwordVisible: passwordVisible ?? this.passwordVisible,
      confirmPasswordVisible:
          confirmPasswordVisible ?? this.confirmPasswordVisible,
      registrationSuccess: registrationSuccess ?? this.registrationSuccess,
    );
  }
}

/// Notifier that manages the registration form lifecycle.
class RegisterNotifier extends StateNotifier<RegisterState> {
  /// Creates a [RegisterNotifier].
  ///
  /// If [api] and [tokenStore] are not provided, they are resolved from
  /// [AuthServiceLocator]. If the locator has not been initialised, a
  /// fallback [AuthApi] backed by a fresh [Dio] instance pointed at the
  /// production BFF is created.
  RegisterNotifier({AuthApi? api, SessionTokenStore? tokenStore})
      : _api = api ?? _resolveApi(),
        _tokenStore = tokenStore ?? _resolveTokenStore(),
        super(const RegisterState());

  final AuthApi _api;
  final SessionTokenStore _tokenStore;

  Timer? _displayNameDebounce;

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
  // Field updates
  // ---------------------------------------------------------------------------

  /// Update the display name and trigger an availability check.
  void setDisplayName(String value) {
    state = state.copyWith(
      displayName: value,
      clearError: true,
      isDisplayNameAvailable: true,
    );
    _debounceDisplayNameCheck(value);
  }

  /// Update the email field.
  void setEmail(String value) =>
      state = state.copyWith(email: value, clearError: true);

  /// Update the password field.
  void setPassword(String value) =>
      state = state.copyWith(password: value, clearError: true);

  /// Update the confirm-password field.
  void setConfirmPassword(String value) =>
      state = state.copyWith(confirmPassword: value, clearError: true);

  /// Toggle terms agreement checkbox.
  void toggleTermsAgreement() =>
      state = state.copyWith(agreedToTerms: !state.agreedToTerms);

  /// Toggle password visibility.
  void togglePasswordVisibility() =>
      state = state.copyWith(passwordVisible: !state.passwordVisible);

  /// Toggle confirm-password visibility.
  void toggleConfirmPasswordVisibility() => state = state.copyWith(
        confirmPasswordVisible: !state.confirmPasswordVisible,
      );

  // ---------------------------------------------------------------------------
  // Display name availability check
  // ---------------------------------------------------------------------------

  void _debounceDisplayNameCheck(String name) {
    _displayNameDebounce?.cancel();
    if (name.length < 2) {
      state = state.copyWith(
        isCheckingDisplayName: false,
        isDisplayNameAvailable: true,
      );
      return;
    }
    state = state.copyWith(isCheckingDisplayName: true);
    _displayNameDebounce = Timer(const Duration(milliseconds: 500), () {
      _checkDisplayNameAvailability(name);
    });
  }

  Future<void> _checkDisplayNameAvailability(String name) async {
    try {
      // TODO: call user API to check display name availability
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Simulate: names starting with "taken" are unavailable
      final available = !name.toLowerCase().startsWith('taken');

      if (state.displayName == name) {
        state = state.copyWith(
          isCheckingDisplayName: false,
          isDisplayNameAvailable: available,
        );
      }
    } on Exception {
      if (state.displayName == name) {
        state = state.copyWith(
          isCheckingDisplayName: false,
          isDisplayNameAvailable: true,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Validates and submits the registration.
  ///
  /// Returns `true` on success so the caller can navigate.
  Future<bool> register() async {
    if (!state.canRegister) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _api.register(
        displayName: state.displayName,
        email: state.email,
        password: state.password,
      );

      // Persist tokens from the registration response.
      final accessToken = result['accessToken'] as String;
      final refreshToken = result['refreshToken'] as String;
      final expiresIn = result['expiresIn'] as int? ?? 3600;
      await _tokenStore.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn,
      );

      state = state.copyWith(
        isLoading: false,
        registrationSuccess: true,
      );
      return true;
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  @override
  void dispose() {
    _displayNameDebounce?.cancel();
    super.dispose();
  }
}

/// Riverpod provider for [RegisterNotifier].
final registerProvider =
    StateNotifierProvider.autoDispose<RegisterNotifier, RegisterState>(
  (ref) => RegisterNotifier(),
);
