import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_platform/raver_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HapticService', () {
    const channel = SystemChannels.platform;
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('sends selection feedback through the platform channel', () async {
      await HapticService.selectionClick();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'HapticFeedback.vibrate');
      expect(calls.single.arguments, 'HapticFeedbackType.selectionClick');
    });

    test('sends light impact feedback through the platform channel', () async {
      await HapticService.lightImpact();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'HapticFeedback.vibrate');
      expect(calls.single.arguments, 'HapticFeedbackType.lightImpact');
    });

    test('sends medium impact feedback through the platform channel', () async {
      await HapticService.mediumImpact();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'HapticFeedback.vibrate');
      expect(calls.single.arguments, 'HapticFeedbackType.mediumImpact');
    });
  });
}
