import 'dart:typed_data';

import 'package:gal/gal.dart';

const gallerySaveIsSupported = true;

Future<void> saveImageBytesImpl(
  List<int> bytes, {
  required String name,
}) {
  return Gal.putImageBytes(Uint8List.fromList(bytes), name: name);
}
