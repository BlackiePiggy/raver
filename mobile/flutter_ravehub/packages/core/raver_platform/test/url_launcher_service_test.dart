import 'package:flutter_test/flutter_test.dart';
import 'package:raver_platform/raver_platform.dart';

void main() {
  group('UrlLauncherService', () {
    test('rejects invalid external URLs before launching', () async {
      await expectLater(
        UrlLauncherService.openExternalUrl('not a url'),
        throwsArgumentError,
      );
    });
  });
}
