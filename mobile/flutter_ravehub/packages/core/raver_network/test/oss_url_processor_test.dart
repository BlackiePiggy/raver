import 'package:raver_network/raver_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OssUrlProcessor', () {
    group('process', () {
      test('returns empty string for empty input', () {
        expect(OssUrlProcessor.process(''), equals(''));
      });

      test('upgrades HTTP to HTTPS', () {
        final result = OssUrlProcessor.process(
          'http://cdn.example.com/image.jpg',
        );
        expect(result, startsWith('https://'));
        expect(result, isNot(contains('http://cdn')));
      });

      test('keeps HTTPS URLs as HTTPS', () {
        final result = OssUrlProcessor.process(
          'https://cdn.example.com/image.jpg',
        );
        expect(result, startsWith('https://cdn.example.com/image.jpg'));
        // Should not double-prefix
        expect(
          result,
          isNot(contains('https://https://')),
        );
      });

      test('appends quality and format by default', () {
        final result = OssUrlProcessor.process(
          'https://cdn.example.com/image.jpg',
        );
        expect(result, contains('x-oss-process='));
        expect(result, contains('quality,Q_80'));
        expect(result, contains('format,webp'));
      });

      test('appends width and height resize parameters', () {
        final result = OssUrlProcessor.process(
          'https://cdn.example.com/image.jpg',
          width: 200,
          height: 200,
        );
        expect(result, contains('image/resize,m_fill,w_200,h_200'));
        expect(result, contains('quality,Q_80'));
        expect(result, contains('format,webp'));
      });

      test('appends width-only resize with m_lfit', () {
        final result = OssUrlProcessor.process(
          'https://cdn.example.com/image.jpg',
          width: 300,
        );
        expect(result, contains('image/resize,m_lfit,w_300'));
        expect(result, isNot(contains('h_')));
      });

      test('appends height-only resize with m_lfit', () {
        final result = OssUrlProcessor.process(
          'https://cdn.example.com/image.jpg',
          height: 400,
        );
        expect(result, contains('image/resize,m_lfit,h_400'));
        expect(result, isNot(contains('w_')));
      });

      test('uses custom quality parameter', () {
        final result = OssUrlProcessor.process(
          'https://cdn.example.com/image.jpg',
          quality: 50,
        );
        expect(result, contains('quality,Q_50'));
      });

      test('ignores zero width and height', () {
        final result = OssUrlProcessor.process(
          'https://cdn.example.com/image.jpg',
          width: 0,
          height: 0,
        );
        expect(result, isNot(contains('image/resize')));
      });

      test('appends as extra query param when URL has existing query', () {
        final result = OssUrlProcessor.process(
          'https://cdn.example.com/image.jpg?v=2',
          width: 100,
          height: 100,
        );
        expect(result, contains('?v=2&x-oss-process='));
      });

      test('appends as first query param when URL has no query', () {
        final result = OssUrlProcessor.process(
          'https://cdn.example.com/image.jpg',
          width: 100,
          height: 100,
        );
        expect(result, contains('?x-oss-process='));
      });

      test('segments are joined with slashes', () {
        final result = OssUrlProcessor.process(
          'https://cdn.example.com/image.jpg',
          width: 200,
          height: 200,
          quality: 90,
        );
        // Should look like: image/resize,m_fill,w_200,h_200/quality,Q_90/format,webp
        expect(
          result,
          contains(
            'image/resize,m_fill,w_200,h_200/quality,Q_90/format,webp',
          ),
        );
      });
    });

    group('djAvatar', () {
      test('original size applies no resize', () {
        final result = OssUrlProcessor.djAvatar(
          'https://cdn.example.com/dj.jpg',
          DJAvatarSize.original,
        );
        expect(result, isNot(contains('image/resize')));
        expect(result, contains('quality,Q_80'));
        expect(result, contains('format,webp'));
      });

      test('medium size applies 200x200 resize', () {
        final result = OssUrlProcessor.djAvatar(
          'https://cdn.example.com/dj.jpg',
          DJAvatarSize.medium,
        );
        expect(result, contains('image/resize,m_fill,w_200,h_200'));
      });

      test('small size applies 80x80 resize', () {
        final result = OssUrlProcessor.djAvatar(
          'https://cdn.example.com/dj.jpg',
          DJAvatarSize.small,
        );
        expect(result, contains('image/resize,m_fill,w_80,h_80'));
      });

      test('upgrades HTTP URLs to HTTPS', () {
        final result = OssUrlProcessor.djAvatar(
          'http://cdn.example.com/dj.jpg',
          DJAvatarSize.small,
        );
        expect(result, startsWith('https://'));
      });
    });
  });

  group('DJAvatarSize', () {
    test('original has 0x0 dimensions', () {
      expect(DJAvatarSize.original.width, equals(0));
      expect(DJAvatarSize.original.height, equals(0));
    });

    test('medium has 200x200 dimensions', () {
      expect(DJAvatarSize.medium.width, equals(200));
      expect(DJAvatarSize.medium.height, equals(200));
    });

    test('small has 80x80 dimensions', () {
      expect(DJAvatarSize.small.width, equals(80));
      expect(DJAvatarSize.small.height, equals(80));
    });

    test('has exactly 3 values', () {
      expect(DJAvatarSize.values.length, equals(3));
    });
  });
}
