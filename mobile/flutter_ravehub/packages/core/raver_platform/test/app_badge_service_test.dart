import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_platform/raver_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppBadgeService', () {
    const channel = MethodChannel('com.ravehub.app_badge');
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

    test('sets app badge count through the platform channel', () async {
      await AppBadgeService.setBadgeCount(12);

      expect(calls, hasLength(1));
      expect(calls.single.method, 'setBadgeCount');
      expect(calls.single.arguments, {'count': 12});
    });

    test('normalizes negative badge counts to zero', () async {
      await AppBadgeService.setBadgeCount(-3);

      expect(calls, hasLength(1));
      expect(calls.single.arguments, {'count': 0});
    });

    test('clears app badge through the platform channel', () async {
      await AppBadgeService.clearBadge();

      expect(calls, hasLength(1));
      expect(calls.single.arguments, {'count': 0});
    });
  });
}
