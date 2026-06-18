import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('ShareLinkPayload', () {
    test('parses iOS live share-link payload shape', () {
      final payload = ShareLinkPayload.fromJson({
        'code': 'abc123',
        'shortUrl': 'https://ravehub.top/s/abc123',
        'canonicalUrl': 'https://ravehub.top/set/set-1',
        'deepLink': 'raver://set/set-1',
        'fallbackUrl': 'https://ravehub.top/set/set-1',
        'qrCodeUrl': 'https://cdn.example.com/qr.png',
        'posterUrl': 'https://cdn.example.com/poster.png',
        'title': 'Warehouse closing set',
        'subtitle': 'DJ Alpha · Warehouse',
        'imageUrl': 'https://cdn.example.com/set.jpg',
        'previewType': 'content_card',
        'status': 'active',
      });

      expect(payload.code, 'abc123');
      expect(payload.url, 'https://ravehub.top/s/abc123');
      expect(payload.shortUrl, 'https://ravehub.top/s/abc123');
      expect(payload.canonicalUrl, 'https://ravehub.top/set/set-1');
      expect(payload.deepLink, 'raver://set/set-1');
      expect(payload.posterUrl, 'https://cdn.example.com/poster.png');
      expect(payload.title, 'Warehouse closing set');
      expect(payload.previewType, 'content_card');
    });

    test('supports iOS set target type', () {
      expect(ShareTargetType.fromJson('set'), ShareTargetType.set);
      expect(ShareTargetType.set.toJson(), 'set');
      expect(ShareTargetType.djSet.toJson(), 'dj_set');
    });
  });
}
