import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('WebCheckin', () {
    test('parses nested event and dj objects from live payloads', () {
      final checkin = WebCheckin.fromJson({
        'id': 'checkin-1',
        'userId': 'user-1',
        'eventId': 'event-1',
        'event': {
          'name': 'RaveHub Night',
          'coverImageUrl': 'https://cdn.example.com/event.jpg',
        },
        'djId': 'dj-1',
        'dj': {
          'name': 'DJ Alpha',
          'avatarUrl': 'https://cdn.example.com/dj.jpg',
        },
        'type': 'event',
        'note': 'Front row all night',
        'rating': '5',
        'attendedAt': '2026-06-17T18:00:00Z',
        'createdAt': '2026-06-17T19:00:00Z',
      });

      expect(checkin.eventName, 'RaveHub Night');
      expect(checkin.eventCoverUrl, 'https://cdn.example.com/event.jpg');
      expect(checkin.djName, 'DJ Alpha');
      expect(checkin.djAvatarUrl, 'https://cdn.example.com/dj.jpg');
      expect(checkin.rating, 5);
    });

    test('parses iOS snake_case checkin aliases', () {
      final checkin = WebCheckin.fromJson({
        'id': 'checkin-1',
        'user_id': 'user-1',
        'event_id': 'event-1',
        'event': {
          'name': 'RaveHub Night',
          'cover_image_url': 'https://cdn.example.com/event.jpg',
        },
        'dj_id': 'dj-1',
        'dj': {
          'name': 'DJ Alpha',
          'avatar_url': 'https://cdn.example.com/dj.jpg',
        },
        'type': 'event',
        'note': 'Front row all night',
        'rating': '5',
        'attended_at': '2026-06-17T18:00:00Z',
        'created_at': '2026-06-17T19:00:00Z',
      });

      expect(checkin.userId, 'user-1');
      expect(checkin.eventId, 'event-1');
      expect(checkin.eventName, 'RaveHub Night');
      expect(checkin.eventCoverUrl, 'https://cdn.example.com/event.jpg');
      expect(checkin.djId, 'dj-1');
      expect(checkin.djAvatarUrl, 'https://cdn.example.com/dj.jpg');
      expect(checkin.attendedAt, '2026-06-17T18:00:00Z');
      expect(checkin.createdAt, '2026-06-17T19:00:00Z');
    });
  });

  group('MyCheckinsOverviewResponse', () {
    test('parses stats aliases and flat live timeline payloads', () {
      final overview = MyCheckinsOverviewResponse.fromJson({
        'stats': {
          'eventCount': 3,
          'artistCount': 8,
          'totalDays': '2',
        },
        'timeline': {
          'items': [
            {
              'event': {
                'id': 'event-1',
                'name': 'RaveHub Night',
                'coverImageUrl': 'https://cdn.example.com/event.jpg',
              },
              'attendedAt': '2026-06-17T18:00:00Z',
              'summary': {'artistCount': '4'},
            },
          ],
        },
        'gallerySummary': {
          'topEvents': ['event-1', 'event-2'],
          'topArtists': ['dj-1', 'dj-2', 'dj-3'],
        },
      });

      expect(overview.stats.totalCheckins, 3);
      expect(overview.stats.uniqueEvents, 3);
      expect(overview.stats.uniqueDJs, 8);
      expect(overview.stats.totalDays, 2);
      expect(overview.gallerySummary.eventCount, 2);
      expect(overview.gallerySummary.artistCount, 3);
      expect(overview.timeline, hasLength(1));
      expect(overview.timeline.single.year, 2026);
      expect(overview.timeline.single.items.single.eventId, 'event-1');
      expect(overview.timeline.single.items.single.djCount, 4);
    });
  });
}
