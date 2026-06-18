import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_platform/raver_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaPickerService', () {
    test('profile avatar picker uses square crop and compression settings',
        () async {
      final pickedParams = <PickImageParams>[];
      final croppedParams = <CropImageParams>[];
      final service = MediaPickerService.testing(
        pickImage: (params) async {
          pickedParams.add(params);
          return XFile('/tmp/avatar-source.jpg');
        },
        cropImage: (params) async {
          croppedParams.add(params);
          return CroppedFile('/tmp/avatar-cropped.jpg');
        },
      );

      final path = await service.pickSquareImageFromGalleryInstance();

      expect(path, '/tmp/avatar-cropped.jpg');
      expect(pickedParams.single.source, ImageSource.gallery);
      expect(pickedParams.single.maxWidth, 2048);
      expect(pickedParams.single.maxHeight, 2048);
      expect(pickedParams.single.imageQuality, 88);
      expect(pickedParams.single.requestFullMetadata, isFalse);
      expect(croppedParams.single.sourcePath, '/tmp/avatar-source.jpg');
      expect(croppedParams.single.maxWidth, 1024);
      expect(croppedParams.single.maxHeight, 1024);
      expect(croppedParams.single.compressQuality, 88);
      expect(croppedParams.single.aspectRatio?.ratioX, 1);
      expect(croppedParams.single.aspectRatio?.ratioY, 1);
      expect(croppedParams.single.uiSettings, hasLength(2));
    });

    test('profile background picker uses 5:3 crop and compression settings',
        () async {
      final pickedParams = <PickImageParams>[];
      final croppedParams = <CropImageParams>[];
      final service = MediaPickerService.testing(
        pickImage: (params) async {
          pickedParams.add(params);
          return XFile('/tmp/background-source.jpg');
        },
        cropImage: (params) async {
          croppedParams.add(params);
          return CroppedFile('/tmp/background-cropped.jpg');
        },
      );

      final path = await service.pickProfileBackgroundImageInstance();

      expect(path, '/tmp/background-cropped.jpg');
      expect(pickedParams.single.source, ImageSource.gallery);
      expect(pickedParams.single.maxWidth, 3000);
      expect(pickedParams.single.maxHeight, 1800);
      expect(pickedParams.single.imageQuality, 88);
      expect(pickedParams.single.requestFullMetadata, isFalse);
      expect(croppedParams.single.sourcePath, '/tmp/background-source.jpg');
      expect(croppedParams.single.maxWidth, 2000);
      expect(croppedParams.single.maxHeight, 1200);
      expect(croppedParams.single.compressQuality, 88);
      expect(croppedParams.single.aspectRatio?.ratioX, 5);
      expect(croppedParams.single.aspectRatio?.ratioY, 3);
      expect(croppedParams.single.uiSettings, hasLength(2));
    });

    test('camera avatar picker uses the same square profile settings',
        () async {
      PickImageParams? pickedParams;
      CropImageParams? croppedParams;
      final service = MediaPickerService.testing(
        pickImage: (params) async {
          pickedParams = params;
          return XFile('/tmp/camera-source.jpg');
        },
        cropImage: (params) async {
          croppedParams = params;
          return CroppedFile('/tmp/camera-cropped.jpg');
        },
      );

      final path = await service.takeSquareImageInstance();

      expect(path, '/tmp/camera-cropped.jpg');
      expect(pickedParams?.source, ImageSource.camera);
      expect(pickedParams?.maxWidth, 2048);
      expect(pickedParams?.maxHeight, 2048);
      expect(pickedParams?.imageQuality, 88);
      expect(croppedParams?.maxWidth, 1024);
      expect(croppedParams?.maxHeight, 1024);
      expect(croppedParams?.compressQuality, 88);
      expect(croppedParams?.aspectRatio?.ratioX, 1);
      expect(croppedParams?.aspectRatio?.ratioY, 1);
    });
  });
}
