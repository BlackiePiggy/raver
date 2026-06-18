import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('WebDJSet', () {
    test('parses iOS live statistics and nested DJ avatar aliases', () {
      final set = WebDJSet.fromJson({
        'id': 'set-1',
        'djId': 'dj-1',
        'title': 'Sunrise closing set',
        'slug': 'sunrise-closing-set',
        'description': 'Peak-hour recording',
        'thumbnailUrl': 'https://cdn.example.com/set.jpg',
        'videoUrl': 'https://video.example.com/set.mp4',
        'videoAuthorName': 'RaveHub',
        'platform': 'direct',
        'videoId': 'video-1',
        'duration': '3660',
        'recordedAt': '2026-06-01T20:00:00Z',
        'venue': 'Warehouse',
        'eventId': 'event-1',
        'eventName': 'RaveHub Night',
        'viewCount': 12034,
        'likeCount': '87',
        'commentCount': 6,
        'trackCount': 2,
        'isVerified': true,
        'createdAt': '2026-06-02T00:00:00Z',
        'updatedAt': '2026-06-03T00:00:00Z',
        'uploadedById': 'user-1',
        'dj': {
          'id': 'dj-1',
          'name': 'DJ Alpha',
          'avatarSmallUrl': 'https://cdn.example.com/dj-small.jpg',
          'avatarUrl': 'https://cdn.example.com/dj.jpg',
        },
        'tracks': [
          {
            'id': 'track-1',
            'position': 1,
            'title': 'Opening',
            'artist': 'Producer A',
            'label': '',
            'startTime': 0,
          },
        ],
      });

      expect(set.djName, 'DJ Alpha');
      expect(set.djAvatarUrl, 'https://cdn.example.com/dj-small.jpg');
      expect(set.slug, 'sunrise-closing-set');
      expect(set.duration, 3660);
      expect(set.viewCount, 12034);
      expect(set.likeCount, 87);
      expect(set.commentCount, 6);
      expect(set.trackCount, 2);
      expect(set.isVerified, isTrue);
      expect(set.updatedAt, '2026-06-03T00:00:00Z');
      expect(set.uploadedById, 'user-1');
      expect(set.tracks, hasLength(1));

      final json = set.toJson();
      expect(json['viewCount'], 12034);
      expect(json['likeCount'], 87);
      expect(json['trackCount'], 2);
      expect(json['isVerified'], isTrue);
    });
  });
}
