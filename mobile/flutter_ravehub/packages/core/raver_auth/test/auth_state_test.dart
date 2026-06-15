import 'package:flutter_test/flutter_test.dart';
import 'package:raver_auth/raver_auth.dart';

void main() {
  group('AuthStatus', () {
    test('has exactly 3 values', () {
      expect(AuthStatus.values.length, equals(3));
    });

    test('has unknown value', () {
      expect(AuthStatus.values, contains(AuthStatus.unknown));
    });

    test('has authenticated value', () {
      expect(AuthStatus.values, contains(AuthStatus.authenticated));
    });

    test('has unauthenticated value', () {
      expect(AuthStatus.values, contains(AuthStatus.unauthenticated));
    });
  });

  group('AuthState', () {
    group('default constructor', () {
      test('defaults to unknown status', () {
        const state = AuthState();
        expect(state.status, equals(AuthStatus.unknown));
        expect(state.userId, isNull);
        expect(state.displayName, isNull);
      });

      test('accepts all parameters', () {
        const state = AuthState(
          status: AuthStatus.authenticated,
          userId: 'u1',
          displayName: 'Alice',
        );
        expect(state.status, equals(AuthStatus.authenticated));
        expect(state.userId, equals('u1'));
        expect(state.displayName, equals('Alice'));
      });
    });

    group('AuthState.unknown()', () {
      test('creates unknown state', () {
        const state = AuthState.unknown();
        expect(state.status, equals(AuthStatus.unknown));
        expect(state.userId, isNull);
        expect(state.displayName, isNull);
      });
    });

    group('AuthState.authenticated()', () {
      test('creates authenticated state with userId', () {
        const state = AuthState.authenticated(userId: 'user-123');
        expect(state.status, equals(AuthStatus.authenticated));
        expect(state.userId, equals('user-123'));
        expect(state.displayName, isNull);
      });

      test('creates authenticated state with displayName', () {
        const state = AuthState.authenticated(
          userId: 'user-456',
          displayName: 'Bob',
        );
        expect(state.status, equals(AuthStatus.authenticated));
        expect(state.userId, equals('user-456'));
        expect(state.displayName, equals('Bob'));
      });
    });

    group('AuthState.unauthenticated()', () {
      test('creates unauthenticated state', () {
        const state = AuthState.unauthenticated();
        expect(state.status, equals(AuthStatus.unauthenticated));
        expect(state.userId, isNull);
        expect(state.displayName, isNull);
      });
    });

    group('copyWith', () {
      test('copies with new status', () {
        const original = AuthState.authenticated(userId: 'u1');
        final copied = original.copyWith(status: AuthStatus.unauthenticated);
        expect(copied.status, equals(AuthStatus.unauthenticated));
        // userId is preserved (not set to null)
        expect(copied.userId, equals('u1'));
      });

      test('copies with new userId', () {
        const original = AuthState.authenticated(
          userId: 'old-id',
          displayName: 'Test',
        );
        final copied = original.copyWith(userId: 'new-id');
        expect(copied.userId, equals('new-id'));
        expect(copied.displayName, equals('Test'));
        expect(copied.status, equals(AuthStatus.authenticated));
      });

      test('copies with new displayName', () {
        const original = AuthState.authenticated(userId: 'u1');
        final copied = original.copyWith(displayName: 'New Name');
        expect(copied.displayName, equals('New Name'));
        expect(copied.userId, equals('u1'));
      });

      test('no-op copy returns equal instance', () {
        const original = AuthState.authenticated(
          userId: 'u1',
          displayName: 'Test',
        );
        final copied = original.copyWith();
        expect(copied, equals(original));
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        const a = AuthState(
          status: AuthStatus.authenticated,
          userId: 'u1',
          displayName: 'Alice',
        );
        const b = AuthState(
          status: AuthStatus.authenticated,
          userId: 'u1',
          displayName: 'Alice',
        );
        expect(a, equals(b));
      });

      test('different status makes them not equal', () {
        const a = AuthState(status: AuthStatus.authenticated, userId: 'u1');
        const b = AuthState(status: AuthStatus.unauthenticated, userId: 'u1');
        expect(a, isNot(equals(b)));
      });

      test('different userId makes them not equal', () {
        const a = AuthState(status: AuthStatus.authenticated, userId: 'u1');
        const b = AuthState(status: AuthStatus.authenticated, userId: 'u2');
        expect(a, isNot(equals(b)));
      });

      test('different displayName makes them not equal', () {
        const a = AuthState(
          status: AuthStatus.authenticated,
          userId: 'u1',
          displayName: 'Alice',
        );
        const b = AuthState(
          status: AuthStatus.authenticated,
          userId: 'u1',
          displayName: 'Bob',
        );
        expect(a, isNot(equals(b)));
      });
    });

    group('hashCode', () {
      test('equal instances have equal hashCodes', () {
        const a = AuthState(
          status: AuthStatus.authenticated,
          userId: 'u1',
          displayName: 'Alice',
        );
        const b = AuthState(
          status: AuthStatus.authenticated,
          userId: 'u1',
          displayName: 'Alice',
        );
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('includes status, userId, and displayName', () {
        const state = AuthState(
          status: AuthStatus.authenticated,
          userId: 'u1',
          displayName: 'Alice',
        );
        final str = state.toString();
        expect(str, contains('authenticated'));
        expect(str, contains('u1'));
        expect(str, contains('Alice'));
      });

      test('includes null values', () {
        const state = AuthState.unauthenticated();
        final str = state.toString();
        expect(str, contains('unauthenticated'));
        expect(str, contains('null'));
      });
    });
  });
}
