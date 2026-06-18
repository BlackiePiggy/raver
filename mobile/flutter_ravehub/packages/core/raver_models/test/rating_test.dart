import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('WebRatingUnit', () {
    test('parses editable description and imageUrl fields', () {
      final unit = WebRatingUnit.fromJson({
        'id': 'unit-1',
        'name': 'Best closing set',
        'description': 'Peak-time finale',
        'imageUrl': 'https://cdn.example.com/unit.jpg',
        'djId': 'dj-1',
        'djName': 'DJ Alpha',
        'rating': 9.2,
        'ratingCount': 42,
        'commentCount': 7,
        'createdAt': '2026-01-01T00:00:00Z',
      });

      expect(unit.description, 'Peak-time finale');
      expect(unit.imageUrl, 'https://cdn.example.com/unit.jpg');
      expect(unit.djAvatarUrl, 'https://cdn.example.com/unit.jpg');
      expect(unit.toJson()['description'], 'Peak-time finale');
      expect(unit.toJson()['imageUrl'], 'https://cdn.example.com/unit.jpg');
    });

    test('parses linked DJ aliases and comment count fallback', () {
      final unit = WebRatingUnit.fromJson({
        'id': 'unit-2',
        'name': 'Warehouse closer',
        'coverImageUrl': 'https://cdn.example.com/cover.jpg',
        'linkedDJs': [
          {
            'id': 'dj-2',
            'name': 'DJ Beta',
            'avatarUrl': 'https://cdn.example.com/dj.jpg',
          },
        ],
        'comments': [
          {'id': 'comment-1'},
          {'id': 'comment-2'},
        ],
        'ratingCount': '8',
        'createdAt': '2026-01-02T00:00:00Z',
      });

      expect(unit.imageUrl, 'https://cdn.example.com/cover.jpg');
      expect(unit.djId, 'dj-2');
      expect(unit.djName, 'DJ Beta');
      expect(unit.djAvatarUrl, 'https://cdn.example.com/dj.jpg');
      expect(unit.ratingCount, 8);
      expect(unit.commentCount, 2);
    });
  });

  group('WebRatingEvent', () {
    test('parses live cover, source event, creator, and units', () {
      final event = WebRatingEvent.fromJson({
        'id': 'rating-1',
        'name': 'Best set',
        'description': 'Vote for the best set',
        'coverImageUrl': 'https://cdn.example.com/rating.jpg',
        'sourceEventId': 'event-1',
        'createdBy': {'id': 'user-1'},
        'createdAt': '2026-01-01T00:00:00Z',
        'units': [
          {
            'id': 'unit-1',
            'name': 'Opening set',
            'djIds': ['dj-1'],
            'ratingCount': 3,
            'commentCount': 1,
          },
        ],
      });

      expect(event.imageUrl, 'https://cdn.example.com/rating.jpg');
      expect(event.eventId, 'event-1');
      expect(event.eventName, 'Best set');
      expect(event.creatorId, 'user-1');
      expect(event.units, hasLength(1));
      expect(event.units!.single.djId, 'dj-1');
    });
  });

  group('WebRatingComment', () {
    test('parses nested live user fields', () {
      final comment = WebRatingComment.fromJson({
        'id': 'comment-1',
        'user': {
          'id': 'user-1',
          'username': 'bass_runner',
          'avatarUrl': 'https://cdn.example.com/user.jpg',
        },
        'score': 4.5,
        'content': 'Massive energy',
        'createdAt': '2026-01-03T00:00:00Z',
      });

      expect(comment.userId, 'user-1');
      expect(comment.displayName, 'bass_runner');
      expect(comment.avatarUrl, 'https://cdn.example.com/user.jpg');
      expect(comment.score, 4.5);
      expect(comment.content, 'Massive energy');
    });
  });
}
