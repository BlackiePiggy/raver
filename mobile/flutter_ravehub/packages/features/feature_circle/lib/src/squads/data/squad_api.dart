import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class SquadApi {
  SquadApi(this._dio);

  final Dio _dio;

  Future<BFFListPage<SquadProfile>> fetchMySquads({
    required int page,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/squads',
      queryParameters: {'page': page, 'limit': limit},
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) => SquadProfile.fromJson(json! as Map<String, dynamic>),
    );
  }

  Future<List<SquadProfile>> fetchRecommendedSquads() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/squads/recommended',
    );
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => SquadProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SquadProfile> createSquad({
    required String name,
    required String description,
    String? coverImageUrl,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/social/squads',
      data: {
        'name': name,
        'description': description,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      },
    );
    return SquadProfile.fromJson(response.data!);
  }

  Future<SquadProfile> fetchSquad({required String id}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/squads/$id',
    );
    return SquadProfile.fromJson(response.data!);
  }

  Future<SquadProfile> updateSquad({
    required String id,
    String? name,
    String? description,
    String? coverImageUrl,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/v1/social/squads/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      },
    );
    return SquadProfile.fromJson(response.data!);
  }

  Future<void> deleteSquad({required String id}) async {
    await _dio.delete<void>('/v1/social/squads/$id');
  }

  Future<List<SquadMemberProfile>> fetchMembers({
    required String squadId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/squads/$squadId/members',
    );
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => SquadMemberProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> joinSquad({required String squadId}) async {
    await _dio.post<void>('/v1/social/squads/$squadId/join');
  }

  Future<void> leaveSquad({required String squadId}) async {
    await _dio.post<void>('/v1/social/squads/$squadId/leave');
  }

  Future<void> inviteMember({
    required String squadId,
    required String userId,
  }) async {
    await _dio.post<void>(
      '/v1/social/squads/$squadId/invite',
      data: {'userId': userId},
    );
  }

  Future<void> kickMember({
    required String squadId,
    required String userId,
  }) async {
    await _dio.post<void>(
      '/v1/social/squads/$squadId/kick',
      data: {'userId': userId},
    );
  }

  Future<List<SquadOfflineActivity>> fetchOfflineActivities({
    required String squadId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/squads/$squadId/offline-activities',
    );
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => SquadOfflineActivity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SquadOfflineActivity> createOfflineActivity({
    required String squadId,
    required String eventId,
    required String startedAt,
    required String endedAt,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/social/squads/$squadId/offline-activities',
      data: {
        'eventId': eventId,
        'startedAt': startedAt,
        'endedAt': endedAt,
      },
    );
    return SquadOfflineActivity.fromJson(response.data!);
  }
}
