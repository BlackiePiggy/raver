import 'package:raver_core/raver_core.dart';
import 'package:test/test.dart';

void main() {
  group('SessionExpirationReason', () {
    test('has all expected values', () {
      expect(SessionExpirationReason.values, containsAll([
        SessionExpirationReason.expired,
        SessionExpirationReason.revoked,
        SessionExpirationReason.idleTimeout,
        SessionExpirationReason.absoluteTimeout,
        SessionExpirationReason.accountInactive,
        SessionExpirationReason.unknown,
      ]));
    });

    test('has exactly 6 values', () {
      expect(SessionExpirationReason.values.length, equals(6));
    });
  });

  group('AccountEnforcementRestriction', () {
    test('stores scope and displayReason', () {
      const restriction = AccountEnforcementRestriction(
        scope: 'post_create',
        displayReason: 'Suspended for spam',
      );
      expect(restriction.scope, equals('post_create'));
      expect(restriction.displayReason, equals('Suspended for spam'));
    });

    test('displayReason is optional', () {
      const restriction = AccountEnforcementRestriction(scope: 'message_send');
      expect(restriction.scope, equals('message_send'));
      expect(restriction.displayReason, isNull);
    });

    test('equality works by value', () {
      const a = AccountEnforcementRestriction(
        scope: 'post_create',
        displayReason: 'reason',
      );
      const b = AccountEnforcementRestriction(
        scope: 'post_create',
        displayReason: 'reason',
      );
      const c = AccountEnforcementRestriction(
        scope: 'different',
        displayReason: 'reason',
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode is consistent with equality', () {
      const a = AccountEnforcementRestriction(scope: 's', displayReason: 'r');
      const b = AccountEnforcementRestriction(scope: 's', displayReason: 'r');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString includes fields', () {
      const restriction = AccountEnforcementRestriction(
        scope: 'post_create',
        displayReason: 'banned',
      );
      final str = restriction.toString();
      expect(str, contains('post_create'));
      expect(str, contains('banned'));
    });
  });

  group('ServiceError', () {
    test('implements Exception', () {
      const error = ServiceError.invalidResponse();
      expect(error, isA<Exception>());
    });

    group('invalidResponse', () {
      test('creates InvalidResponseError', () {
        const error = ServiceError.invalidResponse();
        expect(error, isA<InvalidResponseError>());
      });

      test('toString returns expected value', () {
        expect(
          const ServiceError.invalidResponse().toString(),
          equals('ServiceError.invalidResponse'),
        );
      });
    });

    group('unauthorized', () {
      test('creates UnauthorizedError', () {
        const error = ServiceError.unauthorized();
        expect(error, isA<UnauthorizedError>());
      });

      test('toString returns expected value', () {
        expect(
          const ServiceError.unauthorized().toString(),
          equals('ServiceError.unauthorized'),
        );
      });
    });

    group('sessionExpired', () {
      test('creates SessionExpiredError with reason', () {
        const error =
            ServiceError.sessionExpired(SessionExpirationReason.expired);
        expect(error, isA<SessionExpiredError>());
        expect(
          (error as SessionExpiredError).reason,
          equals(SessionExpirationReason.expired),
        );
      });

      test('accepts all expiration reasons', () {
        for (final reason in SessionExpirationReason.values) {
          final error = ServiceError.sessionExpired(reason);
          expect((error as SessionExpiredError).reason, equals(reason));
        }
      });

      test('toString includes reason', () {
        const error =
            ServiceError.sessionExpired(SessionExpirationReason.revoked);
        expect(
          error.toString(),
          contains('revoked'),
        );
      });
    });

    group('accountInactive', () {
      test('creates AccountInactiveError', () {
        const error = ServiceError.accountInactive();
        expect(error, isA<AccountInactiveError>());
      });

      test('toString returns expected value', () {
        expect(
          const ServiceError.accountInactive().toString(),
          equals('ServiceError.accountInactive'),
        );
      });
    });

    group('accountEnforcementRestricted', () {
      test('creates AccountEnforcementRestrictedError', () {
        const restriction = AccountEnforcementRestriction(
          scope: 'post_create',
          displayReason: 'Violation',
        );
        const error = ServiceError.accountEnforcementRestricted(restriction);
        expect(error, isA<AccountEnforcementRestrictedError>());
        expect(
          (error as AccountEnforcementRestrictedError).restriction,
          equals(restriction),
        );
      });

      test('toString includes restriction details', () {
        const restriction = AccountEnforcementRestriction(
          scope: 'message_send',
        );
        const error = ServiceError.accountEnforcementRestricted(restriction);
        expect(error.toString(), contains('message_send'));
      });
    });

    group('message', () {
      test('creates MessageError with text', () {
        const error = ServiceError.message('Something broke');
        expect(error, isA<MessageError>());
        expect((error as MessageError).text, equals('Something broke'));
      });

      test('toString includes text', () {
        const error = ServiceError.message('server down');
        expect(error.toString(), contains('server down'));
      });
    });

    group('pattern matching (switch exhaustiveness)', () {
      test('all variants are handled by switch', () {
        const errors = <ServiceError>[
          ServiceError.invalidResponse(),
          ServiceError.unauthorized(),
          ServiceError.sessionExpired(SessionExpirationReason.expired),
          ServiceError.accountInactive(),
          ServiceError.accountEnforcementRestricted(
            AccountEnforcementRestriction(scope: 'test'),
          ),
          ServiceError.message('msg'),
        ];

        final labels = errors.map((error) {
          return switch (error) {
            InvalidResponseError() => 'invalidResponse',
            UnauthorizedError() => 'unauthorized',
            SessionExpiredError(:final reason) => 'sessionExpired:$reason',
            AccountInactiveError() => 'accountInactive',
            AccountEnforcementRestrictedError(:final restriction) =>
              'restricted:${restriction.scope}',
            MessageError(:final text) => 'message:$text',
          };
        }).toList();

        expect(labels, [
          'invalidResponse',
          'unauthorized',
          'sessionExpired:SessionExpirationReason.expired',
          'accountInactive',
          'restricted:test',
          'message:msg',
        ]);
      });
    });
  });
}
