import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';

void main() {
  testWidgets('LoadPhase.fromError maps connection failures to offline', (
    tester,
  ) async {
    final phase = LoadPhase.fromError<String>(
      Exception('DioExceptionType.connectionError: failed host lookup'),
    );

    expect(phase, isA<LoadPhaseOffline<String>>());

    await tester.pumpWidget(
      MaterialApp(
        home: LoadPhaseBuilder<String>(
          phase: phase,
          onSuccess: Text.new,
        ),
      ),
    );

    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });

  testWidgets('LoadPhase.fromError maps non-network failures to failure', (
    tester,
  ) async {
    final phase = LoadPhase.fromError<String>(Exception('server said no'));

    expect(phase, isA<LoadPhaseFailure<String>>());

    await tester.pumpWidget(
      MaterialApp(
        home: LoadPhaseBuilder<String>(
          phase: phase,
          onSuccess: Text.new,
        ),
      ),
    );

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
