import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('UserSummary', () {
    group('fromJson', () {
      test('parses all required and optional fields', () {
        final json = <String, dynamic>{
          'id': 'user123',
          'username': 'testuser',
          'displayName': 'Test User',
          'avatarUrl': 'https://cdn.example.com/avatar.jpg',
          'bio': 'Hello world',
        };

        final user = UserSummary.fromJson(json);

        expect(user.id, equals('user123'));
        expect(user.username, equals('testuser'));
        expect(user.displayName, equals('Test User'));
        expect(user.avatarUrl, equals('https://cdn.example.com/avatar.jpg'));
        expect(user.bio, equals('Hello world'));
      });

      test('handles missing optional fields', () {
        final json = <String, dynamic>{
          'id': 'user456',
          'username': 'minimaluser',
          'displayName': 'Minimal User',
        };

        final user = UserSummary.fromJson(json);

        expect(user.id, equals('user456'));
        expect(user.username, equals('minimaluser'));
        expect(user.displayName, equals('Minimal User'));
        expect(user.avatarUrl, isNull);
        expect(user.bio, isNull);
      });

      test('handles null optional fields explicitly', () {
        final json = <String, dynamic>{
          'id': 'user789',
          'username': 'nulluser',
          'displayName': 'Null Fields User',
          'avatarUrl': null,
          'bio': null,
        };

        final user = UserSummary.fromJson(json);

        expect(user.avatarUrl, isNull);
        expect(user.bio, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        const user = UserSummary(
          id: 'u1',
          username: 'bob',
          displayName: 'Bob',
          avatarUrl: 'https://example.com/bob.png',
          bio: 'I am Bob',
        );

        final json = user.toJson();

        expect(json['id'], equals('u1'));
        expect(json['username'], equals('bob'));
        expect(json['displayName'], equals('Bob'));
        expect(json['avatarUrl'], equals('https://example.com/bob.png'));
        expect(json['bio'], equals('I am Bob'));
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        const a = UserSummary(
          id: 'u1',
          username: 'alice',
          displayName: 'Alice',
        );
        const b = UserSummary(
          id: 'u1',
          username: 'alice',
          displayName: 'Alice',
        );
        expect(a, equals(b));
      });

      test('different instances are not equal', () {
        const a = UserSummary(
          id: 'u1',
          username: 'alice',
          displayName: 'Alice',
        );
        const b = UserSummary(
          id: 'u2',
          username: 'bob',
          displayName: 'Bob',
        );
        expect(a, isNot(equals(b)));
      });
    });
  });

  group('Session', () {
    group('fromJson', () {
      test('parses all fields including nested user', () {
        final json = <String, dynamic>{
          'token': 'access-token-abc',
          'refreshToken': 'refresh-token-xyz',
          'accessTokenExpiresIn': 3600,
          'user': {
            'id': 'user123',
            'username': 'testuser',
            'displayName': 'Test User',
            'avatarUrl': 'https://cdn.example.com/avatar.jpg',
            'bio': 'Test bio',
          },
        };

        final session = Session.fromJson(json);

        expect(session.token, equals('access-token-abc'));
        expect(session.refreshToken, equals('refresh-token-xyz'));
        expect(session.accessTokenExpiresIn, equals(3600));
        expect(session.user.id, equals('user123'));
        expect(session.user.username, equals('testuser'));
        expect(session.user.displayName, equals('Test User'));
        expect(
          session.user.avatarUrl,
          equals('https://cdn.example.com/avatar.jpg'),
        );
      });

      test('nested user with missing optional fields', () {
        final json = <String, dynamic>{
          'token': 'tk',
          'refreshToken': 'rt',
          'accessTokenExpiresIn': 7200,
          'user': {
            'id': 'u1',
            'username': 'usr',
            'displayName': 'User',
          },
        };

        final session = Session.fromJson(json);

        expect(session.user.avatarUrl, isNull);
        expect(session.user.bio, isNull);
      });
    });

    group('toJson', () {
      test('serializes session including nested user', () {
        const session = Session(
          token: 'tok',
          refreshToken: 'ref',
          accessTokenExpiresIn: 1800,
          user: UserSummary(
            id: 'u1',
            username: 'bob',
            displayName: 'Bob',
          ),
        );

        final json = session.toJson();

        expect(json['token'], equals('tok'));
        expect(json['refreshToken'], equals('ref'));
        expect(json['accessTokenExpiresIn'], equals(1800));
        expect(json['user'], isA<Map<String, dynamic>>());
        expect((json['user'] as Map<String, dynamic>)['id'], equals('u1'));
      });
    });
  });

  group('UserProfile', () {
    group('fromJson', () {
      test('parses all required and optional fields', () {
        final json = <String, dynamic>{
          'id': 'p1',
          'username': 'profileuser',
          'displayName': 'Profile User',
          'avatarUrl': 'https://cdn.example.com/profile.jpg',
          'bio': 'My bio',
          'followerCount': 100,
          'followingCount': 50,
          'friendCount': 25,
          'ageBand': '18-24',
          'isFollowing': true,
          'isBlocked': false,
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.id, equals('p1'));
        expect(profile.username, equals('profileuser'));
        expect(profile.displayName, equals('Profile User'));
        expect(profile.followerCount, equals(100));
        expect(profile.followingCount, equals(50));
        expect(profile.friendCount, equals(25));
        expect(profile.ageBand, equals('18-24'));
        expect(profile.isFollowing, isTrue);
        expect(profile.isBlocked, isFalse);
      });

      test('optional booleans default to null when absent', () {
        final json = <String, dynamic>{
          'id': 'p2',
          'username': 'user2',
          'displayName': 'User 2',
          'followerCount': 0,
          'followingCount': 0,
          'friendCount': 0,
          'ageBand': '25-34',
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.isFollowing, isNull);
        expect(profile.isBlocked, isNull);
        expect(profile.avatarUrl, isNull);
        expect(profile.bio, isNull);
      });
    });
  });

  group('AuthSessionItem', () {
    group('fromJson', () {
      test('parses all fields', () {
        final json = <String, dynamic>{
          'id': 'sess-001',
          'deviceInfo': 'iPhone 15 Pro, iOS 18.0',
          'ipAddress': '192.168.1.1',
          'lastActiveAt': '2026-06-14T10:30:00Z',
          'createdAt': '2026-06-01T08:00:00Z',
          'isCurrent': true,
        };

        final item = AuthSessionItem.fromJson(json);

        expect(item.id, equals('sess-001'));
        expect(item.deviceInfo, equals('iPhone 15 Pro, iOS 18.0'));
        expect(item.ipAddress, equals('192.168.1.1'));
        expect(item.lastActiveAt, equals('2026-06-14T10:30:00Z'));
        expect(item.createdAt, equals('2026-06-01T08:00:00Z'));
        expect(item.isCurrent, isTrue);
      });

      test('isCurrent can be false', () {
        final json = <String, dynamic>{
          'id': 'sess-002',
          'deviceInfo': 'Pixel 8, Android 15',
          'ipAddress': '10.0.0.1',
          'lastActiveAt': '2026-06-10T12:00:00Z',
          'createdAt': '2026-05-20T09:00:00Z',
          'isCurrent': false,
        };

        final item = AuthSessionItem.fromJson(json);
        expect(item.isCurrent, isFalse);
      });
    });
  });
}
