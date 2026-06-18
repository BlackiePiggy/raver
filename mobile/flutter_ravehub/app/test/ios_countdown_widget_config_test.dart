import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Runner entitlements include countdown widget app group', () {
    final entitlements =
        File('ios/Runner/Runner.entitlements').readAsStringSync();

    expect(entitlements, contains('com.apple.security.application-groups'));
    expect(entitlements, contains('group.com.ravehub.app'));
  });
}
