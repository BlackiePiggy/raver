import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_design_system/raver_design_system.dart';

Widget _buildApp(Widget child) {
  return MaterialApp(
    theme: RaverThemeData.darkTheme(),
    home: MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 3),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('RemoteCoverImage', () {
    test('processes OSS URLs with resize, quality, and webp format', () {
      final processed = RemoteCoverImage.processOssUrl(
        'https://bucket.oss-cn-shanghai.aliyuncs.com/covers/event.jpg',
        targetWidth: 300,
        targetHeight: 180,
      );

      expect(
        processed,
        'https://bucket.oss-cn-shanghai.aliyuncs.com/covers/event.jpg'
        '?x-oss-process=image/resize,w_300,h_180/quality,q_85/format,webp',
      );
    });

    test('does not add duplicate processing parameters', () {
      const url = 'https://bucket.oss-cn-shanghai.aliyuncs.com/covers/event.jpg'
          '?x-oss-process=image/resize,w_300';

      expect(RemoteCoverImage.processOssUrl(url, targetWidth: 600), url);
    });

    test('leaves non-OSS URLs unchanged', () {
      const url = 'https://cdn.example.com/covers/event.jpg';

      expect(RemoteCoverImage.processOssUrl(url, targetWidth: 600), url);
    });

    testWidgets('passes physical dimensions to local memory cache', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          const RemoteCoverImage(
            url: 'https://bucket.oss-cn-shanghai.aliyuncs.com/u/avatar.jpg',
            width: 120,
            height: 80,
          ),
        ),
      );

      final image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );

      expect(image.memCacheWidth, 360);
      expect(image.memCacheHeight, 240);
      expect(image.imageUrl, contains('w_360,h_240'));
      expect(image.imageUrl, contains('/quality,q_85/format,webp'));
    });
  });
}
