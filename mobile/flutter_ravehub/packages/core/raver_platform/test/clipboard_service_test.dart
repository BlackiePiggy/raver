import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_platform/raver_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClipboardService', () {
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

    test('copies text through the platform clipboard channel', () async {
      await ClipboardService.copyText('https://ravehub.top/users/123');

      expect(calls, hasLength(1));
      expect(calls.single.method, 'Clipboard.setData');
      expect(calls.single.arguments, {
        'text': 'https://ravehub.top/users/123',
      });
    });

    test('rejects empty text before calling the platform channel', () async {
      await expectLater(
        ClipboardService.copyText(''),
        throwsArgumentError,
      );

      expect(calls, isEmpty);
    });
  });
}
