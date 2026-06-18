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

  Future<WebRatingEvent> updateRatingEvent({
    required String id,
    required String name,
    required String description,
    String? imageUrl,
  }) {
    return _api.updateRatingEvent(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl,
    );
  }

  Future<WebRatingEvent> fetchRatingEvent({required String id}) {
    return _api.fetchRatingEvent(id: id);
  }

  Future<ShareLinkPayload> resolveRatingEventShareLink({
    required WebRatingEvent event,
    String channel = 'system_share',
  }) {
    return _api.resolveRatingEventShareLink(event: event, channel: channel);
  }

  Future<List<WebRatingUnit>> fetchRatingUnits({required String ratingId}) {
    return _api.fetchRatingUnits(ratingId: ratingId);
  }

  Future<WebRatingUnit> fetchRatingUnit({required String unitId}) {
    return _api.fetchRatingUnit(unitId: unitId);
  }

  Future<ShareLinkPayload> resolveRatingUnitShareLink({
    required String ratingId,
    required WebRatingUnit unit,
    String channel = 'system_share',
  }) {
    return _api.resolveRatingUnitShareLink(
      ratingId: ratingId,
      unit: unit,
      channel: channel,
    );
  }

  Future<WebRatingUnit> createRatingUnit({
    required String ratingId,
    required String name,
    required String djId,
    String description = '',
    String? imageUrl,
  }) {
    return _api.createRatingUnit(
      ratingId: ratingId,
      name: name,
      djId: djId,
      description: description,
      imageUrl: imageUrl,
    );
  }

  Future<WebRatingUnit> updateRatingUnit({
    required String unitId,
    required String name,
    required String description,
    required String djId,
    String? imageUrl,
  }) {
    return _api.updateRatingUnit(
      unitId: unitId,
      name: name,
      description: description,
      djId: djId,
      imageUrl: imageUrl,
    );
  }

  Future<String> uploadRatingImage({
    required String localPath,
    String? ratingEventId,
    String? ratingUnitId,
    String? usage,
  }) {
    return _api.uploadRatingImage(
      localPath: localPath,
      ratingEventId: ratingEventId,
      ratingUnitId: ratingUnitId,
      usage: usage,
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
