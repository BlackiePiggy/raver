import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('LiveApiPayload', () {
    test('unwraps nested object envelopes recursively', () {
      final object = LiveApiPayload.object({
        'data': {
          'payload': {
            'result': {'id': 'post-1', 'content': 'hi'},
          },
        },
      });

      expect(object['id'], 'post-1');
      expect(object['content'], 'hi');
    });

    test('extracts list items from common live envelopes', () {
      final items = LiveApiPayload.items({
        'data': {
          'items': [
            {'id': 'a'},
            {'id': 'b'},
          ],
        },
      });

      expect(items, hasLength(2));
      expect((items.first as Map<String, dynamic>)['id'], 'a');
    });

    test('builds a typed list page with nested pagination', () {
      final page = LiveApiPayload.listPage<String>(
        {
          'data': {
            'items': [
              {'name': 'alpha'},
              {'name': 'beta'},
            ],
            'pagination': {
              'page': '2',
              'limit': 10,
              'total': '22',
              'total_pages': '3',
            },
          },
        },
        (json) => json['name'] as String,
      );

      expect(page.items, ['alpha', 'beta']);
      expect(page.pagination?.page, 2);
      expect(page.pagination?.totalPages, 3);
    });

    test('extracts feed-style cursor from object or root envelopes', () {
      expect(
        LiveApiPayload.cursor({
          'data': {
            'items': const [],
            'next_cursor': 'cursor-a',
          },
        }),
        'cursor-a',
      );
      expect(LiveApiPayload.cursor({'nextCursor': 42}), '42');
    });

    test('unwraps discover-specific object aliases', () {
      expect(
        LiveApiPayload.object({
          'data': {
            'ranking': {'id': 'ranking-1'},
          },
        })['id'],
        'ranking-1',
      );
      expect(
        LiveApiPayload.object({
          'payload': {
            'festival': {'id': 'festival-1'},
          },
        })['id'],
        'festival-1',
      );
      expect(
        LiveApiPayload.object({
          'result': {
            'label': {'id': 'label-1'},
          },
        })['id'],
        'label-1',
      );
      expect(
        LiveApiPayload.object({
          'data': {
            'event': {'id': 'event-1'},
          },
        })['id'],
        'event-1',
      );
    });

    test('extracts custom keyed lists for news and lineup import payloads', () {
      final articles = LiveApiPayload.items(
        {
          'data': {
            'articles': [
              {'id': 'news-1'},
            ],
          },
        },
        itemKeys: const ['articles', 'items', 'data'],
      );
      final matches = LiveApiPayload.items(
        {
          'payload': {
            'matches': [
              {'djName': 'DJ A'},
            ],
          },
        },
        itemKeys: const ['matches', 'items', 'data'],
      );

      expect((articles.single as Map<String, dynamic>)['id'], 'news-1');
      expect((matches.single as Map<String, dynamic>)['djName'], 'DJ A');
    });
  });
}
