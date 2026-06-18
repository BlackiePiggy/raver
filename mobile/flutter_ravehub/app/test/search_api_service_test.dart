import 'package:dio/dio.dart';
import 'package:feature_discover/feature_discover.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_models/raver_models.dart';

void main() {
  group('SearchApiService', () {
    test('uses the iOS live search endpoint and query contract', () async {
      late RequestOptions capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedOptions = options;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'query': 'rave',
                    'tab': 'peopleSquads',
                    'items': const [],
                    'countsByTab': {'peopleSquads': 0},
                  },
                ),
              );
            },
          ),
        );

      final result = await SearchApiService(dio).searchGlobal(
        query: ' rave ',
        tab: 'peopleSquads',
        limit: 120,
        locale: 'en',
      );

      expect(capturedOptions.path, '/v1/search');
      expect(capturedOptions.queryParameters, {
        'q': 'rave',
        'tab': 'peopleSquads',
        'limit': 80,
        'locale': 'en',
      });
      expect(result.tab, GlobalSearchTab.peopleSquads);
      expect(result.countsByTab, {'peopleSquads': 0});
    });

    test('omits empty search keyword like iOS', () async {
      late RequestOptions capturedOptions;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedOptions = options;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'query': '',
                    'tab': 'genreTree',
                    'items': const [],
                  },
                ),
              );
            },
          ),
        );

      final result = await SearchApiService(dio).searchGlobal(
        query: '   ',
        tab: 'genreTree',
        limit: 0,
      );

      expect(capturedOptions.path, '/v1/search');
      expect(capturedOptions.queryParameters.containsKey('q'), isFalse);
      expect(capturedOptions.queryParameters['limit'], 1);
      expect(result.tab, GlobalSearchTab.genreTree);
    });
  });
}
