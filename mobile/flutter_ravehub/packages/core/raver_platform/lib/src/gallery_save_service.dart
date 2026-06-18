import 'src_gallery_save_service_stub.dart'
    if (dart.library.io) 'src_gallery_save_service_io.dart';

/// Saves generated images into the user's photo gallery when the platform
/// provides a native gallery bridge.
class GallerySaveService {
  const GallerySaveService._();

  static bool get isSupported => gallerySaveIsSupported;

  static Future<void> saveImageBytes(
    List<int> bytes, {
    required String name,
  }) =>
      saveImageBytesImpl(bytes, name: name);
}
