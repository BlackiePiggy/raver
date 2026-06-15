import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

final labelApiProvider = Provider<LabelApi>((ref) {
  throw UnimplementedError(
    'labelApiProvider must be overridden with a Dio instance',
  );
});

class LabelApi {
  LabelApi(this._dio);
  final Dio _dio;

  Future<List<LearnLabel>> fetchLabels({int page = 1}) async {
    final response = await _dio.get<List<dynamic>>(
      '/v1/learn/labels',
      queryParameters: {'page': page},
    );
    final list = response.data ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(LearnLabel.fromJson)
        .toList();
  }

  Future<LearnLabel> fetchLabelDetail(String labelId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/v1/learn/labels/$labelId');
    return LearnLabel.fromJson(response.data!);
  }
}
