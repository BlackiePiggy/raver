import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class SquadApi {
  SquadApi(this._dio);

  final Dio _dio;

  Future<BFFListPage<SquadProfile>> fetchMySquads({
    required int page,
    required int limit,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/squads/mine',
      queryParameters: {'page': page, 'limit': limit},
    );
    return LiveApiPayload.listPage<SquadProfile>(
      response.data,
      SquadProfile.fromJson,
    );
  }

  Future<List<SquadProfile>> fetchRecommendedSquads() async {
    final response = await _dio.get<dynamic>('/v1/squads/recommended');
    return LiveApiPayload.items(response.data)
        .whereType<Map<String, dynamic>>()
        .map(SquadProfile.fromJson)
        .toList();
  }

  Future<SquadProfile> createSquad({
    required String name,
    required String description,
    String? coverImageUrl,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/squads',
      data: {
        'name': name,
        'description': description,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      },
    );
    return SquadProfile.fromJson(LiveApiPayload.object(response.data));
  }

  Future<SquadProfile> fetchSquad({required String id}) async {
    final response = await _dio.get<dynamic>('/v1/squads/$id/profile');
    return SquadProfile.fromJson(LiveApiPayload.object(response.data));
  }

  Future<SquadProfile> updateSquad({
    required String id,
    String? name,
    String? description,
    String? coverImageUrl,
  }) async {
    final response = await _dio.patch<dynamic>(
      '/v1/squads/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      },
    );
    return SquadProfile.fromJson(LiveApiPayload.object(response.data));
  }

  Future<void> deleteSquad({required String id}) async {
    await _dio.delete<void>('/v1/squads/$id');
  }

  Future<String> uploadSquadAvatar({
    required String squadId,
    required String localPath,
  }) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(localPath),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/squads/$squadId/avatar',
      data: formData,
    );
    final data = response.data ?? const <String, dynamic>{};
    final url = data['avatarURL'] ?? data['avatarUrl'] ?? data['url'];
    if (url is String && url.isNotEmpty) return url;
    throw StateError('Squad avatar upload response did not include a URL.');
  }

  Future<List<SquadMemberProfile>> fetchMembers({
    required String squadId,
  }) async {
    final response = await _dio.get<dynamic>('/v1/squads/$squadId/profile');
    final profile = LiveApiPayload.object(response.data);
    final items = profile['members'] as List<dynamic>? ?? [];
    return items
        .map((e) => SquadMemberProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> joinSquad({required String squadId}) async {
    await _dio.post<void>('/v1/squads/$squadId/join');
  }

  Future<void> leaveSquad({required String squadId}) async {
    await _dio.post<void>('/v1/squads/$squadId/leave');
  }

  Future<void> inviteMember({
    required String squadId,
    required String userId,
  }) async {
    await _dio.post<void>(
      '/v1/squads/$squadId/invite',
      data: {'userId': userId},
    );
  }

  Future<void> kickMember({
    required String squadId,
    required String userId,
  }) async {
    await _dio.post<void>(
      '/v1/squads/$squadId/members/$userId/remove',
      data: {'userId': userId},
    );
  }

  Future<List<SquadOfflineActivity>> fetchOfflineActivities({
    required String squadId,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/squads/$squadId/offline-activities/history',
    );
    return LiveApiPayload.items(response.data)
        .whereType<Map<String, dynamic>>()
        .map(SquadOfflineActivity.fromJson)
        .toList();
  }

  Future<SquadOfflineActivity> createOfflineActivity({
    required String squadId,
    required String eventId,
    required String startedAt,
    required String endedAt,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/squads/$squadId/offline-activities',
      data: {'eventId': eventId, 'startedAt': startedAt, 'endedAt': endedAt},
    );
    return SquadOfflineActivity.fromJson(LiveApiPayload.object(response.data));
  }
}
