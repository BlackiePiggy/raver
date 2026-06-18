import 'package:flutter/foundation.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Wraps [image_picker] and [image_cropper] to provide a convenient API
/// for selecting and cropping images and videos.
class MediaPickerService {
  /// Creates a [MediaPickerService].
  ///
  /// An [ImagePicker] instance can be injected for testing; otherwise
  /// the default singleton is used.
  MediaPickerService({ImagePicker? picker}) : this._(picker ?? ImagePicker());

  MediaPickerService._(ImagePicker picker)
      : _pickImage = _defaultPickImage(picker),
        _pickVideo = _defaultPickVideo(picker),
        _pickMultiImage = _defaultPickMultiImage(picker),
        _cropImage = _defaultCropImage();

  @visibleForTesting
  MediaPickerService.testing({
    required Future<XFile?> Function(PickImageParams params) pickImage,
    required Future<CroppedFile?> Function(CropImageParams params) cropImage,
    Future<XFile?> Function({required ImageSource source})? pickVideo,
    Future<List<XFile>> Function({required int limit})? pickMultiImage,
  })  : _pickImage = pickImage,
        _cropImage = cropImage,
        _pickVideo = pickVideo ?? (({required source}) async => null),
        _pickMultiImage = pickMultiImage ?? (({required limit}) async => []);

  static const _avatarSpec = _ImageTransformSpec(
    pickMaxWidth: 2048,
    pickMaxHeight: 2048,
    cropMaxWidth: 1024,
    cropMaxHeight: 1024,
    imageQuality: 88,
    compressQuality: 88,
    aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
  );

  static const _profileBackgroundSpec = _ImageTransformSpec(
    pickMaxWidth: 3000,
    pickMaxHeight: 1800,
    cropMaxWidth: 2000,
    cropMaxHeight: 1200,
    imageQuality: 88,
    compressQuality: 88,
    aspectRatio: CropAspectRatio(ratioX: 5, ratioY: 3),
  );

  final Future<XFile?> Function(PickImageParams params) _pickImage;
  final Future<XFile?> Function({required ImageSource source}) _pickVideo;
  final Future<List<XFile>> Function({required int limit}) _pickMultiImage;
  final Future<CroppedFile?> Function(CropImageParams params) _cropImage;

  static Future<XFile?> Function(PickImageParams params) _defaultPickImage(
    ImagePicker picker,
  ) {
    return (params) => picker.pickImage(
          source: params.source,
          maxWidth: params.maxWidth,
          maxHeight: params.maxHeight,
          imageQuality: params.imageQuality,
          requestFullMetadata: params.requestFullMetadata,
        );
  }

  static Future<XFile?> Function({required ImageSource source})
      _defaultPickVideo(ImagePicker picker) {
    return ({required source}) => picker.pickVideo(source: source);
  }

  static Future<List<XFile>> Function({required int limit})
      _defaultPickMultiImage(ImagePicker picker) {
    return ({required limit}) => picker.pickMultiImage(limit: limit);
  }

  static Future<CroppedFile?> Function(CropImageParams params)
      _defaultCropImage() {
    return (params) => ImageCropper().cropImage(
          sourcePath: params.sourcePath,
          maxWidth: params.maxWidth,
          maxHeight: params.maxHeight,
          aspectRatio: params.aspectRatio,
          compressQuality: params.compressQuality,
          uiSettings: params.uiSettings,
        );
  }

  /// Convenience static image picker used by older feature code.
  static Future<String?> pickImage({
    ImageSource source = ImageSource.gallery,
  }) =>
      MediaPickerService().pickImageInstance(source: source);

  /// Picks and crops a square image from the gallery.
  static Future<String?> pickSquareImageFromGallery() =>
      MediaPickerService().pickSquareImageFromGalleryInstance();

  /// Takes and crops a square image with the camera.
  static Future<String?> takeSquareImage() =>
      MediaPickerService().takeSquareImageInstance();

  /// Picks and crops a profile background image from the gallery.
  static Future<String?> pickProfileBackgroundImage() =>
      MediaPickerService().pickProfileBackgroundImageInstance();

  /// Picks and crops a square avatar image from the gallery.
  Future<String?> pickSquareImageFromGalleryInstance() {
    return pickAndCropImage(
      source: ImageSource.gallery,
      spec: _avatarSpec,
    );
  }

  /// Takes and crops a square avatar image with the camera.
  Future<String?> takeSquareImageInstance() {
    return pickAndCropImage(
      source: ImageSource.camera,
      spec: _avatarSpec,
    );
  }

  /// Picks and crops a profile background image from the gallery.
  Future<String?> pickProfileBackgroundImageInstance() {
    return pickAndCropImage(
      source: ImageSource.gallery,
      spec: _profileBackgroundSpec,
    );
  }

  /// Picks a single image from the given [source] and returns its file path,
  /// or `null` if the user cancelled.
  Future<String?> pickImageInstance({
    ImageSource source = ImageSource.gallery,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    bool requestFullMetadata = true,
  }) async {
    try {
      final file = await _pickImage(
        PickImageParams(
          source: source,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          imageQuality: imageQuality,
          requestFullMetadata: requestFullMetadata,
        ),
      );
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
    _ImageTransformSpec? spec,
  }) async {
    final effectiveSpec = spec;
    final imagePath = await pickImageInstance(
      source: source,
      maxWidth: effectiveSpec?.pickMaxWidth,
      maxHeight: effectiveSpec?.pickMaxHeight,
      imageQuality: effectiveSpec?.imageQuality,
      requestFullMetadata: effectiveSpec == null,
    );
    if (imagePath == null) return null;

    try {
      final cropAspectRatio = effectiveSpec?.aspectRatio ?? aspectRatio;
      final croppedFile = await _cropImage(
        CropImageParams(
          sourcePath: imagePath,
          maxWidth: effectiveSpec?.cropMaxWidth,
          maxHeight: effectiveSpec?.cropMaxHeight,
          aspectRatio: cropAspectRatio,
          compressQuality: effectiveSpec?.compressQuality ?? 90,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              lockAspectRatio: cropAspectRatio != null,
            ),
            IOSUiSettings(
              title: 'Crop Image',
              aspectRatioLockEnabled: cropAspectRatio != null,
            ),
          ],
        ),
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
      final file = await _pickVideo(source: source);
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
      final files = await _pickMultiImage(limit: maxCount);
      return files.map((f) => f.path).toList();
    } on Exception {
      return [];
    }
  }
}

class _ImageTransformSpec {
  const _ImageTransformSpec({
    required this.pickMaxWidth,
    required this.pickMaxHeight,
    required this.cropMaxWidth,
    required this.cropMaxHeight,
    required this.imageQuality,
    required this.compressQuality,
    required this.aspectRatio,
  });

  final double pickMaxWidth;
  final double pickMaxHeight;
  final int cropMaxWidth;
  final int cropMaxHeight;
  final int imageQuality;
  final int compressQuality;
  final CropAspectRatio aspectRatio;
}

@visibleForTesting
class PickImageParams {
  /// Creates test-visible image picker parameters.
  const PickImageParams({
    required this.source,
    this.maxWidth,
    this.maxHeight,
    this.imageQuality,
    required this.requestFullMetadata,
  });

  /// Image source to open.
  final ImageSource source;

  /// Maximum picked image width before crop.
  final double? maxWidth;

  /// Maximum picked image height before crop.
  final double? maxHeight;

  /// Picker compression quality before crop.
  final int? imageQuality;

  /// Whether full image metadata should be requested.
  final bool requestFullMetadata;
}

@visibleForTesting
class CropImageParams {
  /// Creates test-visible cropper parameters.
  const CropImageParams({
    required this.sourcePath,
    this.maxWidth,
    this.maxHeight,
    this.aspectRatio,
    required this.compressQuality,
    required this.uiSettings,
  });

  /// Local path passed into the cropper.
  final String sourcePath;

  /// Maximum cropped image width.
  final int? maxWidth;

  /// Maximum cropped image height.
  final int? maxHeight;

  /// Locked crop aspect ratio.
  final CropAspectRatio? aspectRatio;

  /// Cropper compression quality.
  final int compressQuality;

  /// Platform-specific cropper UI settings.
  final List<PlatformUiSettings> uiSettings;
}
