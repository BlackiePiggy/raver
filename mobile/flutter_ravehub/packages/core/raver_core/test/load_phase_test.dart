import 'package:raver_core/raver_core.dart';
import 'package:test/test.dart';

void main() {
  group('LoadPhase', () {
    group('factory constructors', () {
      test('idle() creates LoadPhaseIdle', () {
        const phase = LoadPhase<String>.idle();
        expect(phase, isA<LoadPhaseIdle<String>>());
      });

      test('initialLoading() creates LoadPhaseLoading', () {
        const phase = LoadPhase<String>.initialLoading();
        expect(phase, isA<LoadPhaseLoading<String>>());
      });

      test('success(data) creates LoadPhaseSuccess with data', () {
        const phase = LoadPhase<String>.success('hello');
        expect(phase, isA<LoadPhaseSuccess<String>>());
        expect((phase as LoadPhaseSuccess<String>).data, equals('hello'));
      });

      test('empty() creates LoadPhaseEmpty', () {
        const phase = LoadPhase<int>.empty();
        expect(phase, isA<LoadPhaseEmpty<int>>());
      });

      test('failure(error) creates LoadPhaseFailure with message', () {
        const phase = LoadPhase<int>.failure('Something went wrong');
        expect(phase, isA<LoadPhaseFailure<int>>());
        expect(
          (phase as LoadPhaseFailure<int>).error,
          equals('Something went wrong'),
        );
      });

      test('offline(error) creates LoadPhaseOffline with message', () {
        const phase = LoadPhase<int>.offline('No connection');
        expect(phase, isA<LoadPhaseOffline<int>>());
        expect(
          (phase as LoadPhaseOffline<int>).error,
          equals('No connection'),
        );
      });
    });

    group('errorMessage', () {
      test('returns null for idle', () {
        const phase = LoadPhase<String>.idle();
        expect(phase.errorMessage, isNull);
      });

      test('returns null for loading', () {
        const phase = LoadPhase<String>.initialLoading();
        expect(phase.errorMessage, isNull);
      });

      test('returns null for success', () {
        const phase = LoadPhase<String>.success('data');
        expect(phase.errorMessage, isNull);
      });

      test('returns null for empty', () {
        const phase = LoadPhase<String>.empty();
        expect(phase.errorMessage, isNull);
      });

      test('returns error string for failure', () {
        const phase = LoadPhase<String>.failure('fail');
        expect(phase.errorMessage, equals('fail'));
      });

      test('returns error string for offline', () {
        const phase = LoadPhase<String>.offline('offline msg');
        expect(phase.errorMessage, equals('offline msg'));
      });
    });

    group('isBlocking', () {
      test('idle is blocking', () {
        const phase = LoadPhase<String>.idle();
        expect(phase.isBlocking, isTrue);
      });

      test('initialLoading is blocking', () {
        const phase = LoadPhase<String>.initialLoading();
        expect(phase.isBlocking, isTrue);
      });

      test('success is not blocking', () {
        const phase = LoadPhase<String>.success('data');
        expect(phase.isBlocking, isFalse);
      });

      test('empty is not blocking', () {
        const phase = LoadPhase<String>.empty();
        expect(phase.isBlocking, isFalse);
      });

      test('failure is not blocking', () {
        const phase = LoadPhase<String>.failure('err');
        expect(phase.isBlocking, isFalse);
      });

      test('offline is not blocking', () {
        const phase = LoadPhase<String>.offline('err');
        expect(phase.isBlocking, isFalse);
      });
    });

    group('pattern matching (switch exhaustiveness)', () {
      test('all cases are handled via switch expression', () {
        const phases = <LoadPhase<String>>[
          LoadPhase.idle(),
          LoadPhase.initialLoading(),
          LoadPhase.success('data'),
          LoadPhase.empty(),
          LoadPhase.failure('err'),
          LoadPhase.offline('offline'),
        ];

        final labels = phases.map((phase) {
          return switch (phase) {
            LoadPhaseIdle() => 'idle',
            LoadPhaseLoading() => 'loading',
            LoadPhaseSuccess(:final data) => 'success:$data',
            LoadPhaseEmpty() => 'empty',
            LoadPhaseFailure(:final error) => 'failure:$error',
            LoadPhaseOffline(:final error) => 'offline:$error',
          };
        }).toList();

        expect(labels, [
          'idle',
          'loading',
          'success:data',
          'empty',
          'failure:err',
          'offline:offline',
        ]);
      });
    });

    group('toString', () {
      test('idle toString', () {
        expect(
          const LoadPhase<int>.idle().toString(),
          equals('LoadPhase.idle'),
        );
      });

      test('initialLoading toString', () {
        expect(
          const LoadPhase<int>.initialLoading().toString(),
          equals('LoadPhase.initialLoading'),
        );
      });

      test('success toString includes data', () {
        expect(
          const LoadPhase<String>.success('hello').toString(),
          equals('LoadPhase.success(hello)'),
        );
      });

      test('empty toString', () {
        expect(
          const LoadPhase<int>.empty().toString(),
          equals('LoadPhase.empty'),
        );
      });

      test('failure toString includes error', () {
        expect(
          const LoadPhase<int>.failure('bad').toString(),
          equals('LoadPhase.failure(bad)'),
        );
      });

      test('offline toString includes error', () {
        expect(
          const LoadPhase<int>.offline('no wifi').toString(),
          equals('LoadPhase.offline(no wifi)'),
        );
      });
    });

    group('generic type support', () {
      test('works with int payload', () {
        const phase = LoadPhase<int>.success(42);
        expect((phase as LoadPhaseSuccess<int>).data, equals(42));
      });

      test('works with List payload', () {
        final phase = LoadPhase<List<String>>.success(['a', 'b']);
        expect(
          (phase as LoadPhaseSuccess<List<String>>).data,
          equals(['a', 'b']),
        );
      });

      test('works with Map payload', () {
        final phase = LoadPhase<Map<String, int>>.success({'x': 1});
        expect(
          (phase as LoadPhaseSuccess<Map<String, int>>).data,
          equals({'x': 1}),
        );
      });
    });
  });
}
