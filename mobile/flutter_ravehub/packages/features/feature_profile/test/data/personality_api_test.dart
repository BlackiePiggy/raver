import 'package:dio/dio.dart';
import 'package:feature_profile/src/personality/data/personality_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PersonalityApi', () {
    test('normalizes live session questions and answer payloads', () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              if (options.path == '/v1/personality/sessions') {
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: {
                      'payload': {
                        'sessionId': 'personality-session-1',
                        'questions': [
                          {
                            'questionId': 'question-1',
                            'stemText': 'Pick a dance floor mood',
                            'options': [
                              {'optionId': 'option-a', 'text': 'Deep'},
                              {'optionId': 'option-b', 'text': 'Peak'},
                            ],
                          },
                        ],
                      },
                    },
                  ),
                );
                return;
              }
              if (options.path ==
                  '/v1/personality/sessions/personality-session-1/submit') {
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: {
                      'data': {
                        'result': {
                          'code': 'ENFP',
                          'description': 'High-energy connector',
                        },
                        'dimensions': [
                          {'key': 'energy', 'score': 88},
                        ],
                      },
                    },
                  ),
                );
                return;
              }
              handler.reject(DioException(requestOptions: options));
            },
          ),
        );

      final api = PersonalityApi(dio);
      final questions = await api.fetchQuestions();
      final result = await api.submitAnswers(
        answers: const [
          {'questionIndex': 0, 'selectedOption': 0},
        ],
      );

      expect(questions.single['id'], 'question-1');
      expect(questions.single['text'], 'Pick a dance floor mood');
      expect(questions.single['options'], ['Deep', 'Peak']);
      expect(requests.last.data, {
        'answers': [
          {'questionId': 'question-1', 'optionId': 'option-a'},
        ],
      });
      expect(result['typeCode'], 'ENFP');
      expect(result['description'], 'High-energy connector');
      expect(result['dimensions'], hasLength(1));
      expect(result['matchedDJs'], isEmpty);
    });

    test('normalizes flat result payload aliases', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: {
                    'data': {
                      'typeCode': 'INTJ',
                      'description': 'Focused planner',
                      'matchedDJs': [
                        {'id': 'dj-1'},
                      ],
                    },
                  },
                ),
              );
            },
          ),
        );

      final result = await PersonalityApi(dio).fetchResult();

      expect(result['typeCode'], 'INTJ');
      expect(result['description'], 'Focused planner');
      expect(result['dimensions'], isEmpty);
      expect(result['matchedDJs'], hasLength(1));
    });
  });
}
