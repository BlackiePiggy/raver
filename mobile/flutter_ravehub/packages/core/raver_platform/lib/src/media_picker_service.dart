import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Wraps [image_picker] and [image_cropper] to provide a convenient API
/// for selecting and cropping images and videos.
class MediaPickerService {
  /// Creates a [MediaPickerService].
  ///
  /// An [ImagePicker] instance can be injected for testing; otherwise
  /// the default singleton is used.
  MediaPickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Picks a single image from the given [source] and returns its file path,
  /// or `null` if the user cancelled.
  Future<String?> pickImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final file = await _picker.pickImage(source: source);
      return file?.path;
    } on Exception {
      return null;
    }
  }

  /// Picks an image from [source] and then opens the cropper UI.
  ///
  /// Returns the cropped file path, or `null` if the user cancelled at
  /// any step.
  Future<String?> pickAndCropImage({
    ImageSource source = ImageSource.gallery,
    CropAspectRatio? aspectRatio,
  }) async {
    final imagePath = await pickImage(source: source);
    if (imagePath == null) return null;

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: aspectRatio,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            lockAspectRatio: aspectRatio != null,
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: aspectRatio != null,
          ),
        ],
      );
      return croppedFile?.path;
    } on Exception {
      return null;
    }
  }

  /// Picks a video from the given [source] and returns its file path,
  /// or `null` if the user cancelled.
  Future<String?> pickVideo({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final file = await _picker.pickVideo(source: source);
      return file?.path;
    } on Exception {
      return null;
    }
  }

  /// Picks multiple images from the gallery and returns their file paths.
  ///
  /// Returns at most [maxCount] images. Returns an empty list if the user
  /// cancelled or an error occurred.
  Future<List<String>> pickMultipleImages({int maxCount = 9}) async {
    try {
      final files = await _picker.pickMultiImage(limit: maxCount);
      return files.map((f) => f.path).toList();
    } on Exception {
      return [];
    }
  }
}
