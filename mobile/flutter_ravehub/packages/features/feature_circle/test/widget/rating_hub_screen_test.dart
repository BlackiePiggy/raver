import 'package:feature_circle/src/ratings/presentation/rating_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raver_models/raver_models.dart';

void main() {
  test('ratingEventAverageScore matches native rated-unit averaging', () {
    const event = WebRatingEvent(
      id: 'rating-1',
      name: 'Ultra Experience Rating',
      description: '',
      imageUrl: '',
      eventId: 'event-1',
      eventName: 'Ultra',
      creatorId: 'u1',
      createdAt: '2026-06-17T00:00:00Z',
      units: [
        WebRatingUnit(
          id: 'unit-1',
          name: 'Mainstage Sound',
          djId: 'dj-1',
          djName: 'DJ A',
          djAvatarUrl: '',
          rating: 8.0,
          ratingCount: 4,
          commentCount: 0,
          createdAt: '2026-06-17T00:00:00Z',
        ),
        WebRatingUnit(
          id: 'unit-2',
          name: 'Visuals',
          djId: 'dj-2',
          djName: 'DJ B',
          djAvatarUrl: '',
          rating: 9.0,
          ratingCount: 2,
          commentCount: 0,
          createdAt: '2026-06-17T00:00:00Z',
        ),
        WebRatingUnit(
          id: 'unit-3',
          name: 'Unrated',
          djId: 'dj-3',
          djName: 'DJ C',
          djAvatarUrl: '',
          rating: 10.0,
          ratingCount: 0,
          commentCount: 0,
          createdAt: '2026-06-17T00:00:00Z',
        ),
      ],
    );

    expect(ratingEventAverageScore(event), 8.5);
  });

  test('ratingStarIconForIndex returns full, half, and empty stars', () {
    expect(
      ratingStarIconForIndex(score: 8.5, starIndex: 1),
      Icons.star,
    );
    expect(
      ratingStarIconForIndex(score: 9.0, starIndex: 5),
      Icons.star_half,
    );
    expect(
      ratingStarIconForIndex(score: 3.0, starIndex: 3),
      Icons.star_border,
    );
  });
}
