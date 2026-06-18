import 'package:raver_core/raver_core.dart';

/// Maps live BFF error envelopes into the shared iOS-parity [ServiceError]
/// domain used by UI state and feature repositories.
class NetworkServiceErrorMapper {
  NetworkServiceErrorMapper._();

  static ServiceError fromBffEnvelope(
    Map<String, dynamic> body, {
    int? statusCode,
  }) {
    final restriction = _restrictionFromPayload(body);
    if (restriction != null) {
      return ServiceError.accountEnforcementRestricted(restriction);
    }

    final reason = sessionExpirationReasonFromPayload(body);
    if (reason == SessionExpirationReason.accountInactive) {
      return const ServiceError.accountInactive();
    }
    if (reason != null) {
      return ServiceError.sessionExpired(reason);
    }

    if (statusCode == 401) {
      return const ServiceError.unauthorized();
    }

    final message = _messageFromPayload(body);
    if (message != null) {
      return ServiceError.message(message);
    }

    return const ServiceError.invalidResponse();
  }

  static SessionExpirationReason? sessionExpirationReasonFromPayload(
    Object? payload,
  ) {
    if (payload is! Map) return null;
    final code = _stringValue(payload['code']) ??
        _stringValue(payload['errorCode']) ??
        _stringValue(payload['error']) ??
        _stringValue(payload['message']) ??
        _stringValue(payload['reason']);
    final nestedData = payload['data'];
    if (code == null && nestedData is Map) {
      return sessionExpirationReasonFromPayload(nestedData);
    }
    return switch (code) {
      'AUTH_SESSION_REVOKED' => SessionExpirationReason.revoked,
      'AUTH_SESSION_IDLE_EXPIRED' => SessionExpirationReason.idleTimeout,
      'AUTH_SESSION_ABSOLUTE_EXPIRED' =>
        SessionExpirationReason.absoluteTimeout,
      'AUTH_ACCOUNT_INACTIVE' ||
      'ACCOUNT_INACTIVE' =>
        SessionExpirationReason.accountInactive,
      'AUTH_REFRESH_TOKEN_INVALID_OR_EXPIRED' ||
      'AUTH_REFRESH_EXPIRED' ||
      'AUTH_REFRESH_TOKEN_MISSING' ||
      'TOKEN_EXPIRED' ||
      'UNAUTHENTICATED' =>
        SessionExpirationReason.expired,
      _ => null,
    };
  }

  static AccountEnforcementRestriction? _restrictionFromPayload(
    Map<dynamic, dynamic> payload,
  ) {
    final direct = payload['restriction'];
    if (direct is Map) return _restrictionFromMap(direct);

    final data = payload['data'];
    if (data is Map) {
      final nested = data['restriction'];
      if (nested is Map) return _restrictionFromMap(nested);
      final enforcement = data['enforcement'];
      if (enforcement is Map) return _restrictionFromMap(enforcement);
    }

    final enforcement = payload['enforcement'];
    if (enforcement is Map) return _restrictionFromMap(enforcement);
    return null;
  }

  static AccountEnforcementRestriction _restrictionFromMap(Map data) {
    return AccountEnforcementRestriction(
      scope: _stringValue(data['scope']) ??
          _stringValue(data['action']) ??
          _stringValue(data['type']) ??
          'unknown',
      displayReason: _stringValue(data['displayReason']) ??
          _stringValue(data['reason']) ??
          _stringValue(data['message']),
    );
  }

  static String? _messageFromPayload(Map<dynamic, dynamic> payload) {
    for (final key in const [
      'message',
      'errorMessage',
      'error_description',
      'errorDescription',
      'detail',
      'error',
      'errorCode',
      'code',
    ]) {
      final value = _stringValue(payload[key]);
      if (value != null) return value;
    }

    final data = payload['data'];
    if (data is Map) return _messageFromPayload(data);
    return null;
  }

  static String? _stringValue(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
