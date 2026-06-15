import 'package:dio/dio.dart';

class QuizApi {
  QuizApi(this._dio);

  final Dio _dio;

  /// Fetch quiz questions.
  Future<List<Map<String, dynamic>>> fetchQuestions() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/quiz/questions',
    );
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  /// Submit quiz answers.
  Future<Map<String, dynamic>> submitAnswers({
    required List<Map<String, dynamic>> answers,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/social/quiz/submit',
      data: {'answers': answers},
    );
    return response.data!;
  }

  /// Fetch quiz result.
  Future<Map<String, dynamic>> fetchResult() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/quiz/result',
    );
    return response.data!;
  }
}
