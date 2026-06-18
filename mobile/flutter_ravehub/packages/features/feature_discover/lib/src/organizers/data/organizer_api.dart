import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

import '../../_shared/discover_dio.dart';

final organizerApiProvider = Provider<OrganizerApi>((ref) {
  return OrganizerApi(ref.watch(discoverDioProvider));
});

class OrganizerApi {
  OrganizerApi(this._dio);
  final Dio _dio;

  Future<List<LearnFestival>> fetchFestivals({int page = 1}) async {
    final response = await _dio.get<dynamic>(
      '/v1/learn/festivals',
      queryParameters: {'page': page},
    );
    return LiveApiPayload.items(
      response.data,
    ).whereType<Map<String, dynamic>>().map(LearnFestival.fromJson).toList();
  }

  Future<LearnFestival> fetchFestivalDetail(String festivalId) async {
    final response = await _dio.get<dynamic>(
      '/v1/learn/festivals/$festivalId',
    );
    return LearnFestival.fromJson(LiveApiPayload.object(response.data));
  }

  Future<ShareLinkPayload> resolveShareLink({
    required LearnFestival festival,
    String channel = 'system_share',
  }) async {
    final url = 'https://ravehub.top/festivals/${festival.id}';
    final response = await _dio.post<dynamic>(
      '/v1/share-links/resolve',
      data: {
        'targetType': 'festival',
        'targetId': festival.id,
        'title': festival.name,
        if (festival.imageUrls != null && festival.imageUrls!.isNotEmpty)
          'imageUrl': festival.imageUrls!.first,
        'url': url,
        'deepLink': 'raver://festivals/${festival.id}',
        'channel': channel,
      },
    );
    return ShareLinkPayload.fromJson(LiveApiPayload.object(response.data));
  }

  Future<FollowedBrandUpdatePreference>
      fetchFollowedBrandUpdatePreference() async {
    final response = await _dio.get<dynamic>(
      '/v1/notification-center/preferences/followed-brand-update',
    );
    return FollowedBrandUpdatePreference.fromJson(
      LiveApiPayload.object(response.data),
    );
  }

  Future<FollowedBrandUpdatePreference> updateFollowedBrandUpdatePreference({
    required bool enabled,
    required List<String> watchedBrandIds,
  }) async {
    final response = await _dio.put<dynamic>(
      '/v1/notification-center/preferences/followed-brand-update',
      data: {
        'enabled': enabled,
        'watchedBrandIds': _normalizeBrandIds(watchedBrandIds),
      },
    );
    return FollowedBrandUpdatePreference.fromJson(
      LiveApiPayload.object(response.data),
    );
  }

  Future<LearnFestival> toggleFestivalFollow(LearnFestival festival) async {
    final preference = await fetchFollowedBrandUpdatePreference();
    final watchedIds = _normalizeBrandIds(preference.watchedBrandIds);
    final wasFollowing = watchedIds.contains(festival.id);
    final nextIds = wasFollowing
        ? watchedIds.where((id) => id != festival.id).toList()
        : [...watchedIds, festival.id];
    final nextPreference = await updateFollowedBrandUpdatePreference(
      enabled: nextIds.contains(festival.id) ? true : preference.enabled,
      watchedBrandIds: nextIds,
    );
    final isFollowing = nextPreference.watchedBrandIds.contains(festival.id);
    final nextFollowerCount = festival.followerCount +
        (isFollowing == (festival.isFollowing ?? false)
            ? 0
            : (isFollowing ? 1 : -1));
    return festival.copyWith(
      isFollowing: isFollowing,
      followerCount: nextFollowerCount < 0 ? 0 : nextFollowerCount,
    );
  }

  /// Creates a new festival entry.
  Future<LearnFestival> createFestival(Map<String, dynamic> payload) async {
    final response = await _dio.post<dynamic>(
      '/v1/learn/festivals',
      data: payload,
    );
    return LearnFestival.fromJson(LiveApiPayload.object(response.data));
  }

  /// Updates an existing festival entry.
  Future<LearnFestival> updateFestival(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<dynamic>(
      '/v1/learn/festivals/$id',
      data: payload,
    );
    return LearnFestival.fromJson(LiveApiPayload.object(response.data));
  }

  /// Uploads a festival cover image and returns the remote URL.
  Future<String> uploadFestivalCover(String localPath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(localPath),
    });
    final response = await _dio.post<dynamic>(
      '/v1/upload/festivals/cover',
      data: formData,
    );
    final object = LiveApiPayload.object(response.data);
    final url = object['url'] ?? object['imageUrl'] ?? object['coverImageUrl'];
    if (url is String && url.isNotEmpty) return url;
    throw StateError('Festival cover upload response did not include a URL.');
  }
}

List<String> _normalizeBrandIds(List<String> ids) {
  final seen = <String>{};
  return [
    for (final id in ids.map((id) => id.trim()).where((id) => id.isNotEmpty))
      if (seen.add(id)) id,
  ];
}

class FollowedBrandUpdatePreference {
  const FollowedBrandUpdatePreference({
    required this.enabled,
    required this.watchedBrandIds,
  });

  final bool enabled;
  final List<String> watchedBrandIds;

  factory FollowedBrandUpdatePreference.fromJson(Map<String, dynamic> json) {
    return FollowedBrandUpdatePreference(
      enabled: json['enabled'] as bool? ?? false,
      watchedBrandIds: (json['watchedBrandIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}
