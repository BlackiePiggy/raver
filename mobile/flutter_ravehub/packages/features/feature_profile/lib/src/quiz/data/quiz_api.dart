import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class QuizApi {
  QuizApi(this._dio);

  final Dio _dio;
  String? _sessionId;
  List<Map<String, dynamic>> _questions = const [];

  /// Fetch quiz questions.
  Future<List<Map<String, dynamic>>> fetchQuestions() async {
    final response = await _dio.post<dynamic>(
      '/v1/quiz/sessions',
      data: {'mode': 'standard'},
    );
    final data = _sessionPayload(response.data);
    _sessionId = data['sessionId'] as String?;
    final items = data['questions'] as List<dynamic>? ?? const [];
    _questions = items
        .map((e) => _normalizeQuestion(e as Map<String, dynamic>))
        .toList();
    return _questions;
  }

  /// Submit quiz answers.
  Future<Map<String, dynamic>> submitAnswers({
    required List<Map<String, dynamic>> answers,
  }) async {
    final sessionId = _sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      throw StateError('Quiz session has not been started.');
    }
    final normalizedAnswers = answers.map(_answerPayload).toList();
    final response = await _dio.post<dynamic>(
      '/v1/quiz/sessions/$sessionId/submit',
      data: {
        'answers': normalizedAnswers,
        'presentedQuestionIds':
            _questions.map((question) => question['id']).toList(),
      },
    );
    return _resultFromPayload(_sessionPayload(response.data));
  }

  /// Fetch quiz result.
  Future<Map<String, dynamic>> fetchResult() async {
    final response = await _dio.get<dynamic>('/v1/quiz/status');
    return _resultFromPayload(_sessionPayload(response.data));
  }

  Map<String, dynamic> _normalizeQuestion(Map<String, dynamic> json) {
    final options = (json['options'] as List<dynamic>? ?? const [])
        .map((option) => option as Map<String, dynamic>)
        .toList();
    return {
      'id': json['questionId'] ?? json['id'] ?? '',
      'text': json['stemText'] ?? json['text'] ?? '',
      'stemImageUrl': json['stemImageUrl'],
      'options': options
          .map((option) => option['text'] as String? ?? '')
          .toList(growable: false),
      'optionImages': options
          .map((option) => option['imageUrl'] as String?)
          .toList(growable: false),
      '_optionIds': options
          .map((option) => option['optionId'] ?? option['id'] ?? '')
          .toList(growable: false),
      'timeLimitSec': json['timeLimitSec'],
    };
  }

  Map<String, dynamic> _answerPayload(Map<String, dynamic> answer) {
    final questionIndex = answer['questionIndex'] as int? ?? 0;
    final selectedOption = answer['selectedOption'] as int?;
    final question = questionIndex >= 0 && questionIndex < _questions.length
        ? _questions[questionIndex]
        : const <String, dynamic>{};
    final optionIds = question['_optionIds'] as List<dynamic>? ?? const [];
    final optionId = selectedOption != null &&
            selectedOption >= 0 &&
            selectedOption < optionIds.length
        ? optionIds[selectedOption]
        : null;
    return {'questionId': question['id'] ?? '', 'optionId': optionId};
  }

  Map<String, dynamic> _resultFromPayload(Map<String, dynamic> json) {
    final correct = json['correctCount'] ?? json['score'] ?? 0;
    final total = json['totalCount'] ?? json['totalQuestions'] ?? 0;
    return {
      ...json,
      'score': correct,
      'totalQuestions': total,
      'rank': json['rank'] ?? 0,
      'wrongAnswers': json['wrongAnswers'] ?? const [],
    };
  }

  Map<String, dynamic> _sessionPayload(dynamic payload) =>
      LiveApiPayload.object(payload, objectKeys: const ['data', 'payload']);
}
