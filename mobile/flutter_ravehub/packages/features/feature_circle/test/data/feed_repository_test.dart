import 'package:dio/dio.dart';
import 'package:feature_circle/src/feed/data/feed_api.dart';
import 'package:feature_circle/src/feed/data/feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedRepository', () {
    test('parses live BFF feed fixture through repository', () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: {
                    'data': {
                      'posts': [
                        {
                          'id': 'post-1',
                          'content': 'Main stage energy',
                          'images': [
                            'https://cdn.example.com/photo.jpg',
                            'https://cdn.example.com/clip.mp4',
                          ],
                          'author': {
                            'id': 'user-1',
                            'username': 'bass_runner',
                            'displayName': 'Bass Runner',
                            'avatarURL': 'https://cdn.example.com/user.jpg',
                          },
                          'likeCount': 11,
                          'commentCount': 2,
                          'repostCount': 1,
                          'saveCount': 3,
                          'shareCount': 4,
                          'isLiked': true,
                          'eventId': 'event-1',
                          'eventName': 'RaveHub Night',
                          'displayPublishedAt': '2026-06-17T12:00:00Z',
                        },
                      ],
                      'nextCursor': 'cursor-2',
                    },
                  },
                ),
              );
            },
          ),
        );

      final page = await FeedRepository(FeedApi(dio)).fetchFeed(
        limit: 20,
        mode: 'following',
        eventId: 'event-1',
      );

      expect(requests.single.path, '/v1/feed');
      expect(requests.single.queryParameters, {
        'limit': 20,
        'mode': 'following',
        'eventId': 'event-1',
      });
      expect(page.nextCursor, 'cursor-2');
      expect(page.posts, hasLength(1));
      expect(page.posts.single.id, 'post-1');
      expect(page.posts.single.images, ['https://cdn.example.com/photo.jpg']);
      expect(page.posts.single.videos, ['https://cdn.example.com/clip.mp4']);
      expect(page.posts.single.user.displayName, 'Bass Runner');
      expect(
          page.posts.single.user.avatarUrl, 'https://cdn.example.com/user.jpg');
      expect(page.posts.single.isLiked, isTrue);
      expect(page.posts.single.eventName, 'RaveHub Night');
    });
  });
}
