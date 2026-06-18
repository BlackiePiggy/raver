import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('RankingBoard', () {
    test('parses live aliases and numeric years', () {
      final board = RankingBoard.fromJson({
        'boardId': 'dj-top-100',
        'name': 'DJ Top 100',
        'availableYears': ['2026', 2025, 2024.0, null],
      });

      expect(board.id, 'dj-top-100');
      expect(board.title, 'DJ Top 100');
      expect(board.years, [2026, 2025, 2024]);
    });
  });

  group('RankingBoardDetail', () {
    test('parses live detail aliases and ignores malformed entries', () {
      final detail = RankingBoardDetail.fromJson({
        '_id': 'festival-hot',
        'displayName': 'Festival Hot List',
        'selectedYear': '2026',
        'rankings': [
          {
            'position': '1',
            'title': 'Ultra Japan',
            'rankDelta': '-2',
            'festival': {'_id': 'festival-1'},
          },
          'bad-row',
        ],
      });

      expect(detail.id, 'festival-hot');
      expect(detail.title, 'Festival Hot List');
      expect(detail.year, 2026);
      expect(detail.entries, hasLength(1));
      expect(detail.entries.single.rank, 1);
      expect(detail.entries.single.delta, -2);
      expect(detail.entries.single.festivalId, 'festival-1');
    });
  });

  group('RankingEntry', () {
    test('parses nested DJ aliases and nullable delta', () {
      final entry = RankingEntry.fromJson({
        'index': 3,
        'displayName': 'DJ Alpha',
        'change': null,
        'dj': {
          'id': 'dj-1',
          'avatarSmallUrl': 'https://cdn.example.com/dj-small.jpg',
        },
      });

      expect(entry.rank, 3);
      expect(entry.name, 'DJ Alpha');
      expect(entry.delta, isNull);
      expect(entry.djId, 'dj-1');
      expect(entry.djAvatarUrl, 'https://cdn.example.com/dj-small.jpg');
    });
  });
}
