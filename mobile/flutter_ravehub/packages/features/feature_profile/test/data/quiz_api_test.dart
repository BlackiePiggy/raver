import 'package:dio/dio.dart';
import 'package:feature_profile/src/quiz/data/quiz_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuizApi', () {
    test('normalizes live session questions and answer payloads', () async {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              if (options.path == '/v1/quiz/sessions') {
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: {
                      'data': {
                        'sessionId': 'quiz-session-1',
                        'questions': [
                          {
                            'questionId': 'question-1',
                            'stemText': 'Which genre is this?',
                            'stemImageUrl':
                                'https://cdn.ravehub.test/question.webp',
                            'timeLimitSec': 15,
                            'options': [
                              {
                                'optionId': 'option-a',
                                'text': 'Techno',
                                'imageUrl': null,
                              },
                              {
                                'optionId': 'option-b',
                                'text': 'House',
                                'imageUrl':
                                    'https://cdn.ravehub.test/house.webp',
                              },
                            ],
                          },
                        ],
                      },
                    },
                  ),
                );
                return;
              }
              if (options.path == '/v1/quiz/sessions/quiz-session-1/submit') {
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    data: {
                      'payload': {
                        'correctCount': 1,
                        'totalCount': 1,
                        'rank': 9,
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

      final api = QuizApi(dio);
      final questions = await api.fetchQuestions();
      final result = await api.submitAnswers(
        answers: const [
          {'questionIndex': 0, 'selectedOption': 1},
        ],
      );

      expect(questions.single['id'], 'question-1');
      expect(questions.single['text'], 'Which genre is this?');
      expect(
        questions.single['stemImageUrl'],
        'https://cdn.ravehub.test/question.webp',
      );
      expect(questions.single['options'], ['Techno', 'House']);
      expect(questions.single['optionImages'], [
        null,
        'https://cdn.ravehub.test/house.webp',
      ]);
      expect(questions.single['timeLimitSec'], 15);
      expect(requests.last.data, {
        'answers': [
          {'questionId': 'question-1', 'optionId': 'option-b'},
        ],
        'presentedQuestionIds': ['question-1'],
      });
      expect(result['score'], 1);
      expect(result['totalQuestions'], 1);
      expect(result['rank'], 9);
      expect(result['wrongAnswers'], isEmpty);
    });

    test('normalizes status payload aliases', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ravehub.top'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: {
                    'data': {
                      'score': 7,
                      'totalQuestions': 10,
                      'wrongAnswers': [
                        {'questionId': 'question-2'},
                      ],
                    },
                  },
                ),
              );
            },
          ),
        );

      final result = await QuizApi(dio).fetchResult();

      expect(result['score'], 7);
      expect(result['totalQuestions'], 10);
      expect(result['wrongAnswers'], hasLength(1));
    });
  });
}
