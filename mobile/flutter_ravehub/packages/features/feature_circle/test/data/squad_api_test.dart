import 'package:dio/dio.dart';
import 'package:feature_circle/src/squads/data/squad_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SquadApi', () {
    test('fetchMembers reads the live squad profile payload', () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              if (options.path == '/v1/squads/squad-1/profile') {
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'data': {
                        'id': 'squad-1',
                        'name': 'Warehouse Crew',
                        'memberCount': 2,
                        'members': [
                          {
                            'userId': 'user-1',
                            'displayName': 'Bass Runner',
                            'avatarURL': 'https://cdn.example.com/a.jpg',
                            'role': 'owner',
                            'joinedAt': '2026-06-01T12:00:00Z',
                          },
                          {
                            'id': 'user-2',
                            'username': 'laser_friend',
                            'role': 'member',
                          },
                        ],
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

      final members = await SquadApi(dio).fetchMembers(squadId: 'squad-1');

      expect(requests.map((request) => request.path), [
        '/v1/squads/squad-1/profile',
      ]);
      expect(members, hasLength(2));
      expect(members.first.userId, 'user-1');
      expect(members.first.displayName, 'Bass Runner');
      expect(members.first.avatarUrl, 'https://cdn.example.com/a.jpg');
      expect(members.first.role, 'owner');
      expect(members.last.userId, 'user-2');
      expect(members.last.displayName, 'laser_friend');
    });
  });
}
