import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class FollowApi {
  FollowApi(this._dio);

  final Dio _dio;

  /// Fetch following list.
  Future<BFFListPage<UserSummary>> fetchFollowing({
    required String userId,
    required int page,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/users/$userId/following',
      queryParameters: {'page': page, 'limit': limit},
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) => UserSummary.fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Fetch followers list.
  Future<BFFListPage<UserSummary>> fetchFollowers({
    required String userId,
    required int page,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/users/$userId/followers',
      queryParameters: {'page': page, 'limit': limit},
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) => UserSummary.fromJson(json! as Map<String, dynamic>),
    );
  }
}
