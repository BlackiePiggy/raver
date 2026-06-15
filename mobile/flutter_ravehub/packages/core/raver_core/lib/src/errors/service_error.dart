import 'package:meta/meta.dart';

/// The reason a user session was terminated.
///
/// Mirrors the iOS `SessionExpirationReason` enum in `Models.swift`.
enum SessionExpirationReason {
  /// The session token's TTL elapsed naturally.
  expired,

  /// The session was explicitly revoked (e.g. remote sign-out).
  revoked,

  /// The user was inactive for too long.
  idleTimeout,

  /// The absolute session lifetime was exceeded regardless of activity.
  absoluteTimeout,

  /// The account has been deleted or disabled.
  accountInactive,

  /// Catch-all for server-supplied reasons that the client does not yet
  /// recognise.
  unknown,
}

/// Information about an account-level enforcement restriction that prevents
/// the user from performing a specific action scope.
@immutable
class AccountEnforcementRestriction {
  const AccountEnforcementRestriction({
    required this.scope,
    this.displayReason,
  });

  /// The scope that is blocked (e.g. `"post_create"`, `"message_send"`).
  final String scope;

  /// An optional human-readable reason supplied by the moderation service.
  final String? displayReason;

  @override
  String toString() =>
      'AccountEnforcementRestriction(scope: $scope, displayReason: $displayReason)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountEnforcementRestriction &&
          scope == other.scope &&
          displayReason == other.displayReason;

  @override
  int get hashCode => Object.hash(scope, displayReason);
}

/// Errors that can occur when communicating with the RaveHub BFF or when
/// evaluating the response locally.
///
/// Mirrors the iOS `ServiceError` enum in `SocialService.swift`.
sealed class ServiceError implements Exception {
  const ServiceError();

  /// The server returned a response that could not be parsed or was
  /// structurally invalid.
  const factory ServiceError.invalidResponse() = InvalidResponseError;

  /// The request was rejected because the caller is not authenticated.
  const factory ServiceError.unauthorized() = UnauthorizedError;

  /// The authenticated session is no longer valid.
  const factory ServiceError.sessionExpired(SessionExpirationReason reason) =
      SessionExpiredError;

  /// The account has been deactivated or deleted.
  const factory ServiceError.accountInactive() = AccountInactiveError;

  /// The account is under an enforcement restriction that blocks the
  /// requested action.
  const factory ServiceError.accountEnforcementRestricted(
    AccountEnforcementRestriction restriction,
  ) = AccountEnforcementRestrictedError;

  /// A generic, human-readable error message from the server.
  const factory ServiceError.message(String text) = MessageError;
}

/// {@macro service_error.invalidResponse}
class InvalidResponseError extends ServiceError {
  const InvalidResponseError();

  @override
  String toString() => 'ServiceError.invalidResponse';
}

/// {@macro service_error.unauthorized}
class UnauthorizedError extends ServiceError {
  const UnauthorizedError();

  @override
  String toString() => 'ServiceError.unauthorized';
}

/// {@macro service_error.sessionExpired}
class SessionExpiredError extends ServiceError {
  const SessionExpiredError(this.reason);

  /// Why the session ended.
  final SessionExpirationReason reason;

  @override
  String toString() => 'ServiceError.sessionExpired($reason)';
}

/// {@macro service_error.accountInactive}
class AccountInactiveError extends ServiceError {
  const AccountInactiveError();

  @override
  String toString() => 'ServiceError.accountInactive';
}

/// {@macro service_error.accountEnforcementRestricted}
class AccountEnforcementRestrictedError extends ServiceError {
  const AccountEnforcementRestrictedError(this.restriction);

  /// Details of the enforcement restriction.
  final AccountEnforcementRestriction restriction;

  @override
  String toString() =>
      'ServiceError.accountEnforcementRestricted($restriction)';
}

/// {@macro service_error.message}
class MessageError extends ServiceError {
  const MessageError(this.text);

  /// The human-readable error text.
  final String text;

  @override
  String toString() => 'ServiceError.message($text)';
}
