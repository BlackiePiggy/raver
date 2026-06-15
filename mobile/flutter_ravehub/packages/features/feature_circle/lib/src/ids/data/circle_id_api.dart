import 'package:dio/dio.dart';

/// Local data model for Circle ID cards.
///
/// This is a feature-level model since `raver_models` does not include a
/// shared CircleId type.
class CircleIdCard {
  const CircleIdCard({
    required this.id,
    required this.nickname,
    required this.tagline,
    required this.edmtiType,
    required this.avatarUrl,
    required this.gradientIndex,
    required this.checkinCount,
    required this.followerCount,
    required this.contributionScore,
    required this.createdAt,
  });

  final String id;
  final String nickname;
  final String tagline;
  final String edmtiType;
  final String avatarUrl;
  final int gradientIndex;
  final int checkinCount;
  final int followerCount;
  final int contributionScore;
  final String createdAt;

  factory CircleIdCard.fromJson(Map<String, dynamic> json) {
    return CircleIdCard(
      id: json['id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      edmtiType: json['edmtiType'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      gradientIndex: json['gradientIndex'] as int? ?? 0,
      checkinCount: json['checkinCount'] as int? ?? 0,
      followerCount: json['followerCount'] as int? ?? 0,
      contributionScore: json['contributionScore'] as int? ?? 0,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class CircleIdApi {
  CircleIdApi(this._dio);

  final Dio _dio;

  Future<List<CircleIdCard>> fetchMyCircleIds() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/circle-ids',
    );
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => CircleIdCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CircleIdCard> createCircleId({
    required String nickname,
    required String tagline,
    required int gradientIndex,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/social/circle-ids',
      data: {
        'nickname': nickname,
        'tagline': tagline,
        'gradientIndex': gradientIndex,
      },
    );
    return CircleIdCard.fromJson(response.data!);
  }

  Future<CircleIdCard> fetchCircleId({required String id}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/circle-ids/$id',
    );
    return CircleIdCard.fromJson(response.data!);
  }

  Future<CircleIdCard> updateCircleId({
    required String id,
    String? nickname,
    String? tagline,
    int? gradientIndex,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/v1/social/circle-ids/$id',
      data: {
        if (nickname != null) 'nickname': nickname,
        if (tagline != null) 'tagline': tagline,
        if (gradientIndex != null) 'gradientIndex': gradientIndex,
      },
    );
    return CircleIdCard.fromJson(response.data!);
  }
}
