import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS project does not declare an inbound Share Extension target', () {
    final iosDirectory = Directory('ios');
    final extensionPlists = iosDirectory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('Info.plist'))
        .toList();

    final extensionPointIds = extensionPlists
        .map((file) => file.readAsStringSync())
        .where((content) => content.contains('NSExtensionPointIdentifier'))
        .join('\n');

    expect(extensionPointIds, isNot(contains('com.apple.share-services')));
  });
}
