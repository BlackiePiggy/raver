import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('UploadMediaResponse', () {
    test('parses live feed upload payload with optional fields omitted', () {
      final response = UploadMediaResponse.fromJson({
        'url': 'https://cdn.ravehub.top/feed/image.jpg',
        'fileName': 'image.jpg',
        'mimeType': 'image/jpeg',
        'size': '2048',
      });

      expect(response.url, 'https://cdn.ravehub.top/feed/image.jpg');
      expect(response.fileName, 'image.jpg');
      expect(response.mimeType, 'image/jpeg');
      expect(response.size, 2048);
      expect(response.originalUrl, '');
      expect(response.width, 0);
      expect(response.height, 0);
    });
  });
}
