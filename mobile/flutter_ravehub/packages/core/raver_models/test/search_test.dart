import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('GlobalSearchResponse', () {
    test('parses iOS/live snake_case fields and numeric count strings', () {
      final response = GlobalSearchResponse.fromJson({
        'query': 'techno',
        'tab': 'people_squads',
        'counts_by_tab': {
          'people_squads': '7',
          'genre_tree': 3.0,
        },
        'items': [
          {
            'id': 42,
            'type': 'rating_unit',
            'entity_id': 'unit-1',
            'name': 'Warehouse Sound',
            'sub_title': 'Detroit techno',
            'image_url': 'https://cdn.example.com/unit.jpg',
            'deepLink': 'ravehub://ratings/units/unit-1',
            'relevance_score': '8.5',
          },
        ],
      });

      expect(response.tab, GlobalSearchTab.peopleSquads);
      expect(response.countsByTab, {
        'people_squads': 7,
        'genre_tree': 3,
      });

      final item = response.items.single;
      expect(item.id, '42');
      expect(item.type, GlobalSearchItemType.ratingUnit);
      expect(item.entityId, 'unit-1');
      expect(item.title, 'Warehouse Sound');
      expect(item.subtitle, 'Detroit techno');
      expect(item.imageUrl, 'https://cdn.example.com/unit.jpg');
      expect(item.deeplink, 'ravehub://ratings/units/unit-1');
      expect(item.relevanceScore, 8.5);
    });
  });
}
