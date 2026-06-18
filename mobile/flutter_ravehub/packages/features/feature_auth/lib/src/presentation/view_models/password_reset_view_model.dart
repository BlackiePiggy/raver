import 'package:flutter/foundation.dart';

import '../../data/auth_api.dart';
import '../../data/auth_error_message.dart';
import '../../data/auth_service_locator.dart';

/// Immutable snapshot of the password-reset form state.
class PasswordResetState {
  /// Creates a [PasswordResetState].
  const PasswordResetState({
    this.email = '',
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  /// The email address entered by the user.
  final String email;

  /// Whether a network request is in progress.
  final bool isLoading;

  /// A user-facing error message, if any.
  final String? errorMessage;

  /// Whether the reset link was sent successfully.
  final bool isSuccess;

  /// Returns a copy with the given fields replaced.
  PasswordResetState copyWith({
    String? email,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    bool clearError = false,
  }) {
    return PasswordResetState(
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

/// ChangeNotifier that drives the password-reset screen.
class PasswordResetNotifier extends ChangeNotifier {
  /// Creates a [PasswordResetNotifier].
  PasswordResetNotifier({AuthApi? api})
      : _api = api ?? AuthServiceLocator.instance.api;

  final AuthApi _api;

  PasswordResetState _state = const PasswordResetState();

  /// The current state.
  PasswordResetState get state => _state;

  /// Updates the email value.
  void setEmail(String value) {
    _state = _state.copyWith(email: value, clearError: true, isSuccess: false);
    notifyListeners();
  }

  /// Sends a password-reset request to the backend.
  Future<void> requestReset() async {
    final email = _state.email.trim();
    if (email.isEmpty) {
      _state = _state.copyWith(errorMessage: 'Email is required');
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      isLoading: true,
      clearError: true,
      isSuccess: false,
    );
    notifyListeners();

    try {
      await _api.resetPassword(email: email);
      _state = _state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: authUserFacingError(e),
      );
    }
    notifyListeners();
  }
}
