import 'package:raver_models/raver_models.dart';
import 'package:test/test.dart';

void main() {
  group('ContentSubmissionDetail', () {
    test('parses top-level entity id aliases from live payloads', () {
      for (final entry in const {
        'entityId': 'event-1',
        'targetId': 'dj-1',
        'contentId': 'set-1',
        'resourceId': 'news-1',
      }.entries) {
        final detail = ContentSubmissionDetail.fromJson(
          _detailJson()..[entry.key] = entry.value,
        );

        expect(detail.entityId, entry.value);
      }
    });

    test('parses nested entity id aliases from live payloads', () {
      for (final entry in const {
        'entity': 'event-2',
        'target': 'dj-2',
        'content': 'set-2',
        'resource': 'news-2',
      }.entries) {
        final detail = ContentSubmissionDetail.fromJson(
          _detailJson()..[entry.key] = {'id': entry.value},
        );

        expect(detail.entityId, entry.value);
      }
    });

    test('keeps entity id optional for older detail responses', () {
      final detail = ContentSubmissionDetail.fromJson(_detailJson());

      expect(detail.entityId, isNull);
      expect(detail.toJson().containsKey('entityId'), isFalse);
    });

    test('parses status labels from live payload aliases', () {
      final detail = ContentSubmissionDetail.fromJson(
        _detailJson()
          ..['statusLabel'] = '处理失败'
          ..['versions'] = [
            {
              'id': 'version-1',
              'status': 'failed',
              'metadata': {'statusLabel': '处理失败'},
              'createdAt': '2026-06-16T10:00:00Z',
            },
          ],
      );

      expect(detail.statusLabel, '处理失败');
      expect(detail.versions.single.statusLabel, '处理失败');
      expect(detail.toJson()['statusLabel'], '处理失败');
    });

    test('parses nested review decision status label', () {
      final detail = ContentSubmissionDetail.fromJson(
        _detailJson()
          ..['reviewNotes'] = {
            'reviewDecision': {'statusLabel': '未通过'},
          },
      );

      expect(detail.statusLabel, '未通过');
    });
  });
}

Map<String, dynamic> _detailJson() => {
      'id': 'submission-1',
      'entityType': 'event',
      'entityName': 'RaveHub Night',
      'status': 'rejected',
      'versions': [
        {
          'id': 'version-1',
          'status': 'rejected',
          'createdAt': '2026-06-16T10:00:00Z',
        },
      ],
      'reviewNote': 'Please add a flyer.',
      'createdAt': '2026-06-16T09:00:00Z',
    };
