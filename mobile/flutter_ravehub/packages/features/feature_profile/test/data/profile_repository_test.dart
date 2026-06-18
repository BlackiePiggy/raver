import 'package:dio/dio.dart';
import 'package:feature_profile/src/profile_me/data/profile_api.dart';
import 'package:feature_profile/src/profile_me/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileRepository', () {
    test('parses live BFF profile and post fixtures through repository',
        () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              if (options.path == '/v1/users/me') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    data: {
                      'id': 'user-1',
                      'username': 'bass_runner',
                      'displayName': 'Bass Runner',
                      'avatarURL': 'https://cdn.example.com/avatar.jpg',
                      'backgroundURL': 'https://cdn.example.com/bg.jpg',
                      'bio': 'Warehouse regular',
                      'followerCount': 120,
                      'followingCount': 42,
                      'friendCount': 9,
                      'postCount': 18,
                      'ageBand': '25-34',
                    },
                  ),
                );
                return;
              }
              if (options.path == '/v1/users/me/posts') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    data: {
                      'items': [
                        {
                          'id': 'post-1',
                          'content': 'Aftermovie soon',
                          'images': ['https://cdn.example.com/post.jpg'],
                          'user': {
                            'id': 'user-1',
                            'username': 'bass_runner',
                            'displayName': 'Bass Runner',
                          },
                          'createdAt': '2026-06-17T12:00:00Z',
                        },
                      ],
                      'pagination': {
                        'page': 1,
                        'limit': 20,
                        'total': 1,
                        'totalPages': 1,
                      },
                    },
                  ),
                );
                return;
              }
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );

      final repository = ProfileRepository(ProfileApi(dio));
      final profile = await repository.fetchMe();
      final posts = await repository.fetchMyPosts(page: 1);

      expect(profile.id, 'user-1');
      expect(profile.avatarUrl, 'https://cdn.example.com/avatar.jpg');
      expect(profile.backgroundUrl, 'https://cdn.example.com/bg.jpg');
      expect(profile.postCount, 18);
      expect(posts.items.single.id, 'post-1');
      expect(posts.pagination!.total, 1);
      expect(requests.map((request) => request.path), [
        '/v1/users/me',
        '/v1/users/me/posts',
      ]);
      expect(requests.last.queryParameters, {'page': 1, 'limit': 20});
    });
  });
}
