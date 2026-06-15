import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('BFFPagination', () {
    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = <String, dynamic>{
          'page': 1,
          'limit': 20,
          'total': 55,
          'totalPages': 3,
        };

        final pagination = BFFPagination.fromJson(json);

        expect(pagination.page, equals(1));
        expect(pagination.limit, equals(20));
        expect(pagination.total, equals(55));
        expect(pagination.totalPages, equals(3));
      });

      test('handles first page', () {
        final json = <String, dynamic>{
          'page': 1,
          'limit': 10,
          'total': 100,
          'totalPages': 10,
        };

        final pagination = BFFPagination.fromJson(json);
        expect(pagination.page, equals(1));
      });

      test('handles last page', () {
        final json = <String, dynamic>{
          'page': 10,
          'limit': 10,
          'total': 100,
          'totalPages': 10,
        };

        final pagination = BFFPagination.fromJson(json);
        expect(pagination.page, equals(10));
        expect(pagination.totalPages, equals(10));
      });

      test('handles zero total', () {
        final json = <String, dynamic>{
          'page': 1,
          'limit': 20,
          'total': 0,
          'totalPages': 0,
        };

        final pagination = BFFPagination.fromJson(json);
        expect(pagination.total, equals(0));
        expect(pagination.totalPages, equals(0));
      });
    });

    group('toJson roundtrip', () {
      test('serialization preserves all values', () {
        const original = BFFPagination(
          page: 2,
          limit: 15,
          total: 45,
          totalPages: 3,
        );

        final json = original.toJson();
        final restored = BFFPagination.fromJson(json);

        expect(restored.page, equals(original.page));
        expect(restored.limit, equals(original.limit));
        expect(restored.total, equals(original.total));
        expect(restored.totalPages, equals(original.totalPages));
      });
    });

    group('equality', () {
      test('equal values are equal', () {
        const a = BFFPagination(page: 1, limit: 10, total: 50, totalPages: 5);
        const b = BFFPagination(page: 1, limit: 10, total: 50, totalPages: 5);
        expect(a, equals(b));
      });

      test('different values are not equal', () {
        const a = BFFPagination(page: 1, limit: 10, total: 50, totalPages: 5);
        const b = BFFPagination(page: 2, limit: 10, total: 50, totalPages: 5);
        expect(a, isNot(equals(b)));
      });
    });
  });

  group('BFFListPage', () {
    group('fromJson', () {
      test('parses items with custom fromJsonT function', () {
        final json = <String, dynamic>{
          'items': ['alpha', 'beta', 'gamma'],
          'pagination': {
            'page': 1,
            'limit': 10,
            'total': 3,
            'totalPages': 1,
          },
        };

        final page = BFFListPage<String>.fromJson(
          json,
          (obj) => obj as String,
        );

        expect(page.items, equals(['alpha', 'beta', 'gamma']));
        expect(page.pagination, isNotNull);
        expect(page.pagination!.page, equals(1));
        expect(page.pagination!.total, equals(3));
      });

      test('parses items as integers', () {
        final json = <String, dynamic>{
          'items': [1, 2, 3, 4, 5],
          'pagination': {
            'page': 1,
            'limit': 5,
            'total': 5,
            'totalPages': 1,
          },
        };

        final page = BFFListPage<int>.fromJson(
          json,
          (obj) => obj as int,
        );

        expect(page.items, equals([1, 2, 3, 4, 5]));
      });

      test('parses items as maps (simulating model objects)', () {
        final json = <String, dynamic>{
          'items': [
            {'id': '1', 'name': 'Item A'},
            {'id': '2', 'name': 'Item B'},
          ],
          'pagination': {
            'page': 1,
            'limit': 10,
            'total': 2,
            'totalPages': 1,
          },
        };

        final page = BFFListPage<Map<String, dynamic>>.fromJson(
          json,
          (obj) => obj as Map<String, dynamic>,
        );

        expect(page.items.length, equals(2));
        expect(page.items[0]['id'], equals('1'));
        expect(page.items[1]['name'], equals('Item B'));
      });

      test('handles empty items list', () {
        final json = <String, dynamic>{
          'items': <dynamic>[],
          'pagination': {
            'page': 1,
            'limit': 20,
            'total': 0,
            'totalPages': 0,
          },
        };

        final page = BFFListPage<String>.fromJson(
          json,
          (obj) => obj as String,
        );

        expect(page.items, isEmpty);
        expect(page.pagination!.total, equals(0));
      });

      test('handles null pagination', () {
        final json = <String, dynamic>{
          'items': ['x'],
        };

        final page = BFFListPage<String>.fromJson(
          json,
          (obj) => obj as String,
        );

        expect(page.items, equals(['x']));
        expect(page.pagination, isNull);
      });
    });

    group('constructor', () {
      test('creates instance with items and pagination', () {
        const page = BFFListPage<String>(
          items: ['a', 'b'],
          pagination: BFFPagination(
            page: 1,
            limit: 10,
            total: 2,
            totalPages: 1,
          ),
        );

        expect(page.items, equals(['a', 'b']));
        expect(page.pagination!.total, equals(2));
      });

      test('creates instance without pagination', () {
        const page = BFFListPage<int>(items: [1, 2, 3]);

        expect(page.items, equals([1, 2, 3]));
        expect(page.pagination, isNull);
      });
    });
  });
}
