import 'package:flutter/foundation.dart';

/// Represents the current authentication status of the user.
enum AuthStatus {
  /// Initial state before authentication status has been determined.
  unknown,

  /// The user has valid credentials and is signed in.
  authenticated,

  /// The user is not signed in or credentials have been revoked.
  unauthenticated,
}

/// Immutable snapshot of the current authentication state.
@immutable
class AuthState {
  /// Creates an [AuthState].
  const AuthState({
    this.status = AuthStatus.unknown,
    this.userId,
    this.displayName,
  });

  /// Convenience constructor for the initial unknown state.
  const AuthState.unknown() : this();

  /// Convenience constructor for an authenticated state.
  const AuthState.authenticated({
    required String userId,
    String? displayName,
  }) : this(
          status: AuthStatus.authenticated,
          userId: userId,
          displayName: displayName,
        );

  /// Convenience constructor for an unauthenticated state.
  const AuthState.unauthenticated()
      : this(status: AuthStatus.unauthenticated);

  /// The current authentication status.
  final AuthStatus status;

  /// The unique identifier of the authenticated user, if any.
  final String? userId;

  /// The display name of the authenticated user, if any.
  final String? displayName;

  /// Returns a copy of this [AuthState] with the given fields replaced.
  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? displayName,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          userId == other.userId &&
          displayName == other.displayName;

  @override
  int get hashCode => Object.hash(status, userId, displayName);

  @override
  String toString() =>
      'AuthState(status: $status, userId: $userId, displayName: $displayName)';
}
