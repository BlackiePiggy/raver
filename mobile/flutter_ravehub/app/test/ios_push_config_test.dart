import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Runner declares APNS entitlement and remote notification mode', () {
    final entitlements =
        File('ios/Runner/Runner.entitlements').readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(entitlements, contains('aps-environment'));
    expect(infoPlist, contains('UIBackgroundModes'));
    expect(infoPlist, contains('remote-notification'));
  });
}
