import 'package:raver_models/raver_models.dart';

import 'squad_api.dart';

class SquadRepository {
  SquadRepository(this._api);

  final SquadApi _api;

  Future<BFFListPage<SquadProfile>> fetchMySquads({
    required int page,
    int limit = 20,
  }) {
    return _api.fetchMySquads(page: page, limit: limit);
  }

  Future<List<SquadProfile>> fetchRecommendedSquads() {
    return _api.fetchRecommendedSquads();
  }

  Future<SquadProfile> createSquad({
    required String name,
    required String description,
    String? coverImageUrl,
  }) {
    return _api.createSquad(
      name: name,
      description: description,
      coverImageUrl: coverImageUrl,
    );
  }

  Future<SquadProfile> fetchSquad({required String id}) {
    return _api.fetchSquad(id: id);
  }

  Future<SquadProfile> updateSquad({
    required String id,
    String? name,
    String? description,
    String? coverImageUrl,
  }) {
    return _api.updateSquad(
      id: id,
      name: name,
      description: description,
      coverImageUrl: coverImageUrl,
    );
  }

  Future<void> deleteSquad({required String id}) {
    return _api.deleteSquad(id: id);
  }

  Future<List<SquadMemberProfile>> fetchMembers({required String squadId}) {
    return _api.fetchMembers(squadId: squadId);
  }

  Future<void> joinSquad({required String squadId}) {
    return _api.joinSquad(squadId: squadId);
  }

  Future<void> leaveSquad({required String squadId}) {
    return _api.leaveSquad(squadId: squadId);
  }

  Future<void> inviteMember({
    required String squadId,
    required String userId,
  }) {
    return _api.inviteMember(squadId: squadId, userId: userId);
  }

  Future<void> kickMember({
    required String squadId,
    required String userId,
  }) {
    return _api.kickMember(squadId: squadId, userId: userId);
  }

  Future<List<SquadOfflineActivity>> fetchOfflineActivities({
    required String squadId,
  }) {
    return _api.fetchOfflineActivities(squadId: squadId);
  }

  Future<SquadOfflineActivity> createOfflineActivity({
    required String squadId,
    required String eventId,
    required String startedAt,
    required String endedAt,
  }) {
    return _api.createOfflineActivity(
      squadId: squadId,
      eventId: eventId,
      startedAt: startedAt,
      endedAt: endedAt,
    );
  }
}
