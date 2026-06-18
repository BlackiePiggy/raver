import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('SquadProfile', () {
    test('parses live aliases and member profiles', () {
      final profile = SquadProfile.fromJson({
        'id': 'squad-1',
        'name': 'After Hours',
        'avatarURL': 'https://cdn.example.com/squad.jpg',
        'description': 'Late-night crew',
        'memberCount': '12',
        'myRole': 'owner',
        'groupID': 'im-group-1',
        'members': [
          {
            'id': 'user-1',
            'nickname': 'Bass Pilot',
            'avatarURL': 'https://cdn.example.com/user.jpg',
            'joinedAt': '2026-06-01T12:00:00Z',
          },
        ],
      });

      expect(profile.id, 'squad-1');
      expect(profile.avatarUrl, 'https://cdn.example.com/squad.jpg');
      expect(profile.memberCount, 12);
      expect(profile.myRole, 'owner');
      expect(profile.groupId, 'im-group-1');
      expect(profile.members, hasLength(1));
      expect(profile.members!.single.userId, 'user-1');
      expect(profile.members!.single.displayName, 'Bass Pilot');
      expect(profile.members!.single.avatarUrl,
          'https://cdn.example.com/user.jpg');
      expect(profile.members!.single.role, 'member');
    });
  });

  group('SquadOfflineActivity', () {
    test('parses live aliases and participant location fields', () {
      final activity = SquadOfflineActivity.fromJson({
        'id': 'activity-1',
        'squadID': 'squad-1',
        'eventID': 'event-1',
        'eventName': 'RaveHub Night',
        'startedAt': '2026-06-17T10:00:00Z',
        'endedAt': '2026-06-17T18:00:00Z',
        'participants': [
          {
            'id': 'user-2',
            'username': 'tempo_runner',
            'avatarUrl': 'https://cdn.example.com/u2.jpg',
            'latitude': 31.2304,
            'longitude': 121.4737,
            'lastLocationAt': '2026-06-17T12:00:00Z',
          },
        ],
      });

      expect(activity.squadId, 'squad-1');
      expect(activity.eventId, 'event-1');
      expect(activity.status, 'active');
      expect(activity.participants, hasLength(1));
      expect(activity.participants!.single.userId, 'user-2');
      expect(activity.participants!.single.displayName, 'tempo_runner');
      expect(activity.participants!.single.latitude, 31.2304);
      expect(activity.participants!.single.longitude, 121.4737);
    });
  });
}
