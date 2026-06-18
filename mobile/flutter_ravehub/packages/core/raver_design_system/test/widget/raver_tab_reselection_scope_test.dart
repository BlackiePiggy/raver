import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';

void main() {
  testWidgets('listener fires only for matching tab reselection events', (
    tester,
  ) async {
    final controller = RaverTabReselectionController();
    var matchingCount = 0;
    var otherCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: RaverTabReselectionScope(
          controller: controller,
          child: Column(
            children: [
              RaverTabReselectionListener(
                tabIndex: 1,
                onReselected: () => matchingCount++,
                child: const SizedBox(),
              ),
              RaverTabReselectionListener(
                tabIndex: 2,
                onReselected: () => otherCount++,
                child: const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );

    controller.notifyReselected(0);
    await tester.pump();
    expect(matchingCount, 0);
    expect(otherCount, 0);

    controller.notifyReselected(1);
    await tester.pump();
    expect(matchingCount, 1);
    expect(otherCount, 0);

    controller.notifyReselected(2);
    await tester.pump();
    expect(matchingCount, 1);
    expect(otherCount, 1);

    controller.dispose();
  });
}
