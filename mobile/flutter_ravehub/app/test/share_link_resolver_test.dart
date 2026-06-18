import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravehub/router/share_link_resolver.dart';

void main() {
  group('ShareLinkResolver', () {
    test('resolves short links through the live share-link contract', () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              if (options.method == 'GET' &&
                  options.path == '/v1/share-links/abc123') {
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: {
                      'data': {
                        'code': 'abc123',
                        'shortUrl': 'https://ravehub.top/s/abc123',
                        'deepLink': 'raver://community/post/post-1',
                        'canonicalUrl': 'https://ravehub.top/p/post-1',
                        'fallbackUrl': 'https://ravehub.top/p/post-1',
                      },
                    },
                  ),
                );
                return;
              }
              if (options.method == 'POST' &&
                  options.path == '/v1/share-links/abc123/events') {
                handler.resolve(
                  Response<void>(requestOptions: options, statusCode: 204),
                );
                return;
              }
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: 'Unexpected request: ${options.method} ${options.path}',
                ),
              );
            },
          ),
        );

      final path = await ShareLinkResolver(dio).resolve(
        Uri.parse('https://ravehub.top/s/abc123'),
      );

      expect(path, '/circle/post/post-1?shareCode=abc123');
      expect(requests.map((request) => request.path), [
        '/v1/share-links/abc123',
        '/v1/share-links/abc123/events',
      ]);
      expect(requests.last.data, {
        'eventType': 'app_open',
        'channel': 'universal_link',
        'platform': 'flutter',
        'metadata': {
          'source': 'universal_link',
          'incomingURL': 'https://ravehub.top/s/abc123',
        },
      });
    });

    test('uses canonical links locally without network requests', () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );

      final path = await ShareLinkResolver(dio).resolve(
        Uri.parse('https://ravehub.top/e/event-1?shareCode=abc123'),
      );

      expect(path, '/events/event-1?shareCode=abc123');
      expect(requests, isEmpty);
    });
  });
}
