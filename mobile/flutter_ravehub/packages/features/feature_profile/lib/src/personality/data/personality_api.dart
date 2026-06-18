import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class PersonalityApi {
  PersonalityApi(this._dio);

  final Dio _dio;
  String? _sessionId;
  List<Map<String, dynamic>> _questions = const [];

  /// Fetch personality test questions.
  Future<List<Map<String, dynamic>>> fetchQuestions() async {
    final response = await _dio.post<dynamic>(
      '/v1/personality/sessions',
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

  /// Submit personality test answers.
  Future<Map<String, dynamic>> submitAnswers({
    required List<Map<String, dynamic>> answers,
  }) async {
    final sessionId = _sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      throw StateError('Personality session has not been started.');
    }
    final response = await _dio.post<dynamic>(
      '/v1/personality/sessions/$sessionId/submit',
      data: {'answers': answers.map(_answerPayload).toList()},
    );
    return _resultFromPayload(_sessionPayload(response.data));
  }

  /// Fetch personality test result.
  Future<Map<String, dynamic>> fetchResult() async {
    final response = await _dio.get<dynamic>('/v1/personality/result');
    return _resultFromPayload(_sessionPayload(response.data));
  }

  Map<String, dynamic> _normalizeQuestion(Map<String, dynamic> json) {
    final options = (json['options'] as List<dynamic>? ?? const [])
        .map((option) => option as Map<String, dynamic>)
        .toList();
    return {
      'id': json['questionId'] ?? json['id'] ?? '',
      'text': json['stemText'] ?? json['text'] ?? '',
      'options': options
          .map((option) => option['text'] as String? ?? '')
          .toList(growable: false),
      '_optionIds': options
          .map((option) => option['optionId'] ?? option['id'] ?? '')
          .toList(growable: false),
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
    final result = json['result'] is Map<String, dynamic>
        ? json['result'] as Map<String, dynamic>
        : json;
    return {
      ...json,
      'typeCode': result['code'] ?? result['typeCode'] ?? 'XXXX',
      'description': result['description'] ?? '',
      'dimensions': json['dimensions'] ?? const [],
      'matchedDJs': json['matchedDJs'] ?? const [],
    };
  }

  Map<String, dynamic> _sessionPayload(dynamic payload) =>
      LiveApiPayload.object(payload, objectKeys: const ['data', 'payload']);
}
