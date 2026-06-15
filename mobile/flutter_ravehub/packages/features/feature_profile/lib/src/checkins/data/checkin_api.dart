import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class CheckinApi {
  CheckinApi(this._dio);

  final Dio _dio;

  /// Fetch checkin list.
  Future<BFFListPage<WebCheckin>> fetchCheckins({
    required int page,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/checkins',
      queryParameters: {'page': page, 'limit': limit},
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) => WebCheckin.fromJson(json! as Map<String, dynamic>),
    );
  }

  /// Fetch checkin overview statistics.
  Future<MyCheckinsOverviewResponse> fetchOverview() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/checkins/overview',
    );
    return MyCheckinsOverviewResponse.fromJson(response.data!);
  }
}
