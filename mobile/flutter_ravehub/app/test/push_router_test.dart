import 'package:flutter_test/flutter_test.dart';
import 'package:ravehub/push/push_router.dart';

void main() {
  group('PushRouter.resolvePathFromData', () {
    test('prefers direct in-app routes and deep links', () {
      expect(
        PushRouter.resolvePathFromData({'route': '/profile/checkins'}),
        '/profile/checkins',
      );
      expect(
        PushRouter.resolvePathFromData({
          'deepLink': 'raver://circle/ratings/rating-1/units/unit-1',
        }),
        '/circle/ratings/rating-1/units/unit-1',
      );
      expect(
        PushRouter.resolvePathFromData({
          'url': 'https://ravehub.top/profile/checkins',
        }),
        '/profile/checkins',
      );
    });

    test('maps live target type payloads to app routes', () {
      expect(
        PushRouter.resolvePathFromData({
          'targetType': 'rating_unit',
          'targetId': 'unit-1',
          'ratingEventId': 'rating-1',
        }),
        '/circle/ratings/rating-1/units/unit-1',
      );
      expect(
        PushRouter.resolvePathFromData({
          'target_type': 'circle_id',
          'target_id': 'card-1',
        }),
        '/circle/id/card-1',
      );
      expect(
        PushRouter.resolvePathFromData({
          'type': 'content_review',
          'id': 'submission-1',
        }),
        '/profile/publishes/submission-1',
      );
      expect(
        PushRouter.resolvePathFromData({'type': 'my_checkins'}),
        '/profile/checkins',
      );
    });

    test('maps notification categories to inbox routes', () {
      expect(
        PushRouter.resolvePathFromData({'category': 'community_alert'}),
        '/inbox/alerts/community',
      );
      expect(
        PushRouter.resolvePathFromData({'category': 'followed_djs'}),
        '/inbox/followed-djs',
      );
      expect(
        PushRouter.resolvePathFromData({'category': 'content_reviews'}),
        '/inbox/content-reviews',
      );
    });
  });
}
