import 'package:flutter_test/flutter_test.dart';
import 'package:raver_core/raver_core.dart';
import 'package:raver_network/raver_network.dart';

void main() {
  group('NetworkServiceErrorMapper', () {
    test('maps BFF message envelopes to ServiceError.message', () {
      final error = NetworkServiceErrorMapper.fromBffEnvelope({
        'errorCode': 'VALIDATION_FAILED',
        'message': 'Name is required',
      });

      expect(error, isA<MessageError>());
      expect((error as MessageError).text, 'Name is required');
    });

    test('maps 401 envelopes without session reason to unauthorized', () {
      final error = NetworkServiceErrorMapper.fromBffEnvelope(
        {'message': 'Unauthorized'},
        statusCode: 401,
      );

      expect(error, isA<UnauthorizedError>());
    });

    test('maps session expiration codes to typed reasons', () {
      final revoked = NetworkServiceErrorMapper.fromBffEnvelope({
        'errorCode': 'AUTH_SESSION_REVOKED',
        'message': 'signed out elsewhere',
      });
      final idle =
          NetworkServiceErrorMapper.sessionExpirationReasonFromPayload({
        'data': {'code': 'AUTH_SESSION_IDLE_EXPIRED'},
      });

      expect(revoked, isA<SessionExpiredError>());
      expect(
        (revoked as SessionExpiredError).reason,
        SessionExpirationReason.revoked,
      );
      expect(idle, SessionExpirationReason.idleTimeout);
    });

    test('maps account inactive codes to accountInactive', () {
      final error = NetworkServiceErrorMapper.fromBffEnvelope({
        'errorCode': 'AUTH_ACCOUNT_INACTIVE',
        'message': 'disabled',
      });

      expect(error, isA<AccountInactiveError>());
    });

    test('maps enforcement restriction payloads before generic message', () {
      final error = NetworkServiceErrorMapper.fromBffEnvelope({
        'errorCode': 'FORBIDDEN',
        'message': 'blocked',
        'data': {
          'restriction': {
            'scope': 'post_create',
            'displayReason': 'Review required',
          },
        },
      }, statusCode: 403);

      expect(error, isA<AccountEnforcementRestrictedError>());
      final restriction =
          (error as AccountEnforcementRestrictedError).restriction;
      expect(restriction.scope, 'post_create');
      expect(restriction.displayReason, 'Review required');
    });

    test('falls back to invalidResponse for empty envelopes', () {
      final error = NetworkServiceErrorMapper.fromBffEnvelope({});

      expect(error, isA<InvalidResponseError>());
    });
  });
}
