import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('LearnGenreNode', () {
    test('parses live aliases and nullable fields without crashing', () {
      final genre = LearnGenreNode.fromJson({
        'genreId': 'hard-techno',
        'title': 'Hard Techno',
        'parentID': null,
        'fullPath': 'Techno/Hard Techno',
        'desc': null,
        'originRegion': 'Europe',
        'period': 1990,
        'bpm': '140-160',
        'subGenres': [
          {
            '_id': 'schranz',
            'displayName': 'Schranz',
            'path': 'Techno/Hard Techno/Schranz',
          },
        ],
        'soundCues': [
          {
            'name': 'Pressure Tool',
            'artistName': 'Producer A',
            'spotifyURL': null,
            'appleMusicURL': 'https://music.example.com/pressure',
          },
        ],
      });

      expect(genre.id, 'hard-techno');
      expect(genre.name, 'Hard Techno');
      expect(genre.parentId, isEmpty);
      expect(genre.description, isEmpty);
      expect(genre.origin, 'Europe');
      expect(genre.era, '1990');
      expect(genre.bpmRange, '140-160');
      expect(genre.children, hasLength(1));
      expect(genre.children!.single.id, 'schranz');
      expect(genre.soundCueTracks, hasLength(1));
      expect(genre.soundCueTracks!.single.title, 'Pressure Tool');
      expect(genre.soundCueTracks!.single.spotifyUrl, isEmpty);
    });
  });

  group('GenreSunburstNode', () {
    test('parses live aliases and ignores malformed child entries', () {
      final node = GenreSunburstNode.fromJson({
        '_id': 'bass',
        'displayName': 'Bass Music',
        'fullPath': 'Bass Music',
        'hexColor': '#31D0AA',
        'subgenres': [
          {'slug': 'dubstep', 'name': 'Dubstep'},
          'bad-row',
        ],
      });

      expect(node.id, 'bass');
      expect(node.name, 'Bass Music');
      expect(node.path, 'Bass Music');
      expect(node.themeColor, '#31D0AA');
      expect(node.children, hasLength(1));
      expect(node.children!.single.id, 'dubstep');
      expect(node.children!.single.path, 'dubstep');
    });
  });

  group('LearnGenreTreeSummaryNode', () {
    test('parses numeric child count aliases', () {
      final node = LearnGenreTreeSummaryNode.fromJson({
        'slug': 'house',
        'name': 'House',
        'childrenCount': '12',
      });

      expect(node.id, 'house');
      expect(node.path, 'house');
      expect(node.childCount, 12);
    });
  });
}
