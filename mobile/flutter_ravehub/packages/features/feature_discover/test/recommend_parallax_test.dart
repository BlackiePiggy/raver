import 'package:feature_discover/src/recommend/presentation/recommend_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recommendation parallax', () {
    test('matches iOS card scale transition bounds', () {
      expect(recommendationCardScaleForPageDelta(0), 1);
      expect(recommendationCardScaleForPageDelta(1), 0.95);
      expect(recommendationCardScaleForPageDelta(-1), 0.95);
      expect(recommendationCardScaleForPageDelta(4), 0.95);
    });

    test('moves covers opposite directions while staying within image bleed',
        () {
      const cardWidth = 300.0;
      final leftOffset = recommendationCoverParallaxOffset(
        pageDelta: 1,
        cardWidth: cardWidth,
      );
      final centeredOffset = recommendationCoverParallaxOffset(
        pageDelta: 0,
        cardWidth: cardWidth,
      );
      final rightOffset = recommendationCoverParallaxOffset(
        pageDelta: -1,
        cardWidth: cardWidth,
      );

      expect(leftOffset, 48);
      expect(centeredOffset, 20);
      expect(rightOffset, -48);
    });
  });
}
