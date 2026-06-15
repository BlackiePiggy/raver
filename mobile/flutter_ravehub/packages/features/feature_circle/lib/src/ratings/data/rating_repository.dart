import 'package:raver_models/raver_models.dart';

import 'rating_api.dart';

class RatingRepository {
  RatingRepository(this._api);

  final RatingApi _api;

  Future<BFFListPage<WebRatingEvent>> fetchRatings({
    required int page,
    int limit = 20,
    String? status,
  }) {
    return _api.fetchRatings(page: page, limit: limit, status: status);
  }

  Future<WebRatingEvent> createRatingEvent({
    required String name,
    required String description,
    required String eventId,
    String? imageUrl,
  }) {
    return _api.createRatingEvent(
      name: name,
      description: description,
      eventId: eventId,
      imageUrl: imageUrl,
    );
  }

  Future<WebRatingEvent> fetchRatingEvent({required String id}) {
    return _api.fetchRatingEvent(id: id);
  }

  Future<List<WebRatingUnit>> fetchRatingUnits({required String ratingId}) {
    return _api.fetchRatingUnits(ratingId: ratingId);
  }

  Future<WebRatingUnit> createRatingUnit({
    required String ratingId,
    required String name,
    required String djId,
  }) {
    return _api.createRatingUnit(
      ratingId: ratingId,
      name: name,
      djId: djId,
    );
  }

  Future<void> voteRatingUnit({
    required String ratingId,
    required String unitId,
    required double score,
  }) {
    return _api.voteRatingUnit(
      ratingId: ratingId,
      unitId: unitId,
      score: score,
    );
  }

  Future<BFFListPage<WebRatingComment>> fetchUnitComments({
    required String ratingId,
    required String unitId,
    required int page,
    int limit = 20,
  }) {
    return _api.fetchUnitComments(
      ratingId: ratingId,
      unitId: unitId,
      page: page,
      limit: limit,
    );
  }

  Future<WebRatingComment> postUnitComment({
    required String ratingId,
    required String unitId,
    required String content,
    required double score,
  }) {
    return _api.postUnitComment(
      ratingId: ratingId,
      unitId: unitId,
      content: content,
      score: score,
    );
  }
}
