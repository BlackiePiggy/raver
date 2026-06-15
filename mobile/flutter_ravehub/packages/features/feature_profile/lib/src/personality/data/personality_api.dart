import 'package:dio/dio.dart';

class PersonalityApi {
  PersonalityApi(this._dio);

  final Dio _dio;

  /// Fetch personality test questions.
  Future<List<Map<String, dynamic>>> fetchQuestions() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/personality/questions',
    );
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  /// Submit personality test answers.
  Future<Map<String, dynamic>> submitAnswers({
    required List<Map<String, dynamic>> answers,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/social/personality/submit',
      data: {'answers': answers},
    );
    return response.data!;
  }

  /// Fetch personality test result.
  Future<Map<String, dynamic>> fetchResult() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/personality/result',
    );
    return response.data!;
  }
}
