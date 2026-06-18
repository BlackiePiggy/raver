const gallerySaveIsSupported = false;

Future<void> saveImageBytesImpl(
  List<int> bytes, {
  required String name,
}) {
  throw UnsupportedError('Saving images to gallery is not supported here.');
}
