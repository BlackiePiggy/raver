import 'package:flutter_test/flutter_test.dart';
import 'package:raver_platform/raver_platform.dart';

void main() {
  group('AppVersionInfo', () {
    test('formats version with build number', () {
      const info = AppVersionInfo(
        appName: 'RaveHub',
        packageName: 'com.ravehub.app',
        version: '1.2.3',
        buildNumber: '45',
      );

      expect(info.displayVersion, 'v1.2.3 (45)');
    });

    test('formats version without build number', () {
      const info = AppVersionInfo(
        appName: 'RaveHub',
        packageName: 'com.ravehub.app',
        version: '1.2.3',
        buildNumber: '',
      );

      expect(info.displayVersion, 'v1.2.3');
    });
  });
}
