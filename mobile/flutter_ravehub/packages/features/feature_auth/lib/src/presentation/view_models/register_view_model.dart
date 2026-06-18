import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_auth/raver_auth.dart';

import '../../data/auth_api.dart';
import '../../data/auth_error_message.dart';
import '../../data/auth_service_locator.dart';

const _globalRegionCode = 'GLOBAL';
const _japanRegionCode = 'JP';

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
    this.birthYear,
    this.regionCode = _globalRegionCode,
    this.homeCountryCode = 'CN',
    this.homeRegionCode = '310000',
    this.homeCityCode = '310000',
    this.isDisplayNameAvailable = true,
    this.isCheckingDisplayName = false,
    this.displayNameCheckFailed = false,
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

  /// Optional birth year used by regional compliance.
  final int? birthYear;

  /// Regional compliance code. `GLOBAL` does not require age declaration.
  final String regionCode;

  /// Selected registration home-city country code.
  final String homeCountryCode;

  /// Selected registration home-city region/province code.
  final String homeRegionCode;

  /// Selected registration home-city city code.
  final String homeCityCode;

  /// Result of the display-name availability check.
  final bool isDisplayNameAvailable;

  /// Whether a display-name check is currently in progress.
  final bool isCheckingDisplayName;

  /// Whether the latest display-name availability check failed.
  final bool displayNameCheckFailed;

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
  bool get isDisplayNameValid =>
      displayName.length >= 2 && displayName.length <= 24;

  /// Whether the email looks valid.
  bool get isEmailValid {
    if (email.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  /// Whether the password meets strength requirements.
  bool get isPasswordValid => password.length >= 8;

  /// Whether confirm password matches.
  bool get passwordsMatch => password.isNotEmpty && password == confirmPassword;

  /// Whether the selected region requires age declaration.
  bool get requiresAgeDeclaration => regionCode == _japanRegionCode;

  /// Whether the selected age satisfies regional compliance rules.
  bool get isAgeDeclarationValid {
    if (!requiresAgeDeclaration) return true;
    final year = birthYear;
    if (year == null) return false;
    return DateTime.now().year - year >= 13;
  }

  /// iOS-compatible home-city location value.
  String get homeLocationValue =>
      '$homeCountryCode:$homeRegionCode:$homeCityCode';

  /// Overall form validity.
  bool get canRegister =>
      !isLoading &&
      isDisplayNameValid &&
      (isDisplayNameAvailable || displayNameCheckFailed) &&
      !isCheckingDisplayName &&
      isEmailValid &&
      isPasswordValid &&
      passwordsMatch &&
      isAgeDeclarationValid &&
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
    int? birthYear,
    bool clearBirthYear = false,
    String? regionCode,
    String? homeCountryCode,
    String? homeRegionCode,
    String? homeCityCode,
    bool? isDisplayNameAvailable,
    bool? isCheckingDisplayName,
    bool? displayNameCheckFailed,
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
      birthYear: clearBirthYear ? null : (birthYear ?? this.birthYear),
      regionCode: regionCode ?? this.regionCode,
      homeCountryCode: homeCountryCode ?? this.homeCountryCode,
      homeRegionCode: homeRegionCode ?? this.homeRegionCode,
      homeCityCode: homeCityCode ?? this.homeCityCode,
      isDisplayNameAvailable:
          isDisplayNameAvailable ?? this.isDisplayNameAvailable,
      isCheckingDisplayName:
          isCheckingDisplayName ?? this.isCheckingDisplayName,
      displayNameCheckFailed:
          displayNameCheckFailed ?? this.displayNameCheckFailed,
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
  RegisterNotifier({
    AuthApi? api,
    SessionTokenStore? tokenStore,
    RegistrationLocationSaver? registrationLocationSaver,
  })  : _api = api ?? _resolveApi(),
        _tokenStore = tokenStore ?? _resolveTokenStore(),
        _registrationLocationSaver =
            registrationLocationSaver ?? _resolveRegistrationLocationSaver(),
        super(const RegisterState());

  final AuthApi _api;
  final SessionTokenStore _tokenStore;
  final RegistrationLocationSaver? _registrationLocationSaver;

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

  static RegistrationLocationSaver? _resolveRegistrationLocationSaver() {
    try {
      return AuthServiceLocator.instance.registrationLocationSaver;
    } catch (_) {
      return null;
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
      displayNameCheckFailed: false,
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

  /// Update the regional compliance selection.
  void setRegionCode(String value) {
    state = state.copyWith(
      regionCode: value,
      birthYear: value == _japanRegionCode ? _defaultAdultBirthYear() : null,
      clearBirthYear: value != _japanRegionCode,
      clearError: true,
    );
  }

  /// Update the birth year used for regional compliance.
  void setBirthYear(int value) =>
      state = state.copyWith(birthYear: value, clearError: true);

  /// Update the selected home-city country and reset region/city.
  void setHomeCountry({
    required String countryCode,
    required String regionCode,
    required String cityCode,
  }) {
    state = state.copyWith(
      homeCountryCode: countryCode,
      homeRegionCode: regionCode,
      homeCityCode: cityCode,
      clearError: true,
    );
  }

  /// Update the selected home-city region and reset city.
  void setHomeRegion({
    required String regionCode,
    required String cityCode,
  }) {
    state = state.copyWith(
      homeRegionCode: regionCode,
      homeCityCode: cityCode,
      clearError: true,
    );
  }

  /// Update the selected home city.
  void setHomeCity(String cityCode) {
    state = state.copyWith(homeCityCode: cityCode, clearError: true);
  }

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
        displayNameCheckFailed: false,
      );
      return;
    }
    if (name.length > 24) {
      state = state.copyWith(
        isCheckingDisplayName: false,
        isDisplayNameAvailable: false,
        displayNameCheckFailed: false,
      );
      return;
    }
    state = state.copyWith(isCheckingDisplayName: true);
    _displayNameDebounce = Timer(const Duration(milliseconds: 500), () {
      _checkDisplayNameAvailability(name);
    });
  }

  Future<void> _checkDisplayNameAvailability(String name) async {
    final candidate = name.trim();
    try {
      final available = await _api.checkDisplayNameAvailability(
        displayName: candidate,
      );

      if (state.displayName.trim() == candidate) {
        state = state.copyWith(
          isCheckingDisplayName: false,
          isDisplayNameAvailable: available,
          displayNameCheckFailed: false,
        );
      }
    } on Exception {
      if (state.displayName.trim() == candidate) {
        state = state.copyWith(
          isCheckingDisplayName: false,
          isDisplayNameAvailable: true,
          displayNameCheckFailed: true,
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
        birthYear: state.requiresAgeDeclaration ? state.birthYear : null,
        regionCode: state.requiresAgeDeclaration ? state.regionCode : null,
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
      await AuthServiceLocator.instance.authenticatedSessionHandler
          ?.call(result);
      _saveRegistrationLocationInBackground(state.homeLocationValue);

      state = state.copyWith(
        isLoading: false,
        registrationSuccess: true,
      );
      return true;
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: authUserFacingError(e),
      );
      return false;
    }
  }

  void _saveRegistrationLocationInBackground(String location) {
    final saver = _registrationLocationSaver;
    final trimmed = location.trim();
    if (saver == null || trimmed.isEmpty) return;
    unawaited(saver(trimmed));
  }

  @override
  void dispose() {
    _displayNameDebounce?.cancel();
    super.dispose();
  }
}

int _defaultAdultBirthYear() => DateTime.now().year - 18;

/// Riverpod provider for [RegisterNotifier].
final registerProvider =
    StateNotifierProvider.autoDispose<RegisterNotifier, RegisterState>(
  (ref) => RegisterNotifier(),
);
