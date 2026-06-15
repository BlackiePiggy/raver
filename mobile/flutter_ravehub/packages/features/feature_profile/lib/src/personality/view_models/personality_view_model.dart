import 'package:flutter/foundation.dart';
import 'package:raver_design_system/raver_design_system.dart';

import '../data/personality_api.dart';

class PersonalityViewModel extends ChangeNotifier {
  PersonalityViewModel({required PersonalityApi api}) : _api = api;

  final PersonalityApi _api;

  // Questions
  LoadPhase<List<Map<String, dynamic>>> _phase = const LoadPhase.loading();
  LoadPhase<List<Map<String, dynamic>>> get phase => _phase;

  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> get questions => _questions;

  // Current state
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  int get totalQuestions => _questions.length;
  double get progress =>
      totalQuestions > 0 ? (_currentIndex + 1) / totalQuestions : 0;

  // Answers
  final Map<int, int> _answers = {};
  Map<int, int> get answers => Map.unmodifiable(_answers);
  int? get currentAnswer => _answers[_currentIndex];

  // Submission
  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  // Result
  Map<String, dynamic>? _result;
  Map<String, dynamic>? get result => _result;
  bool _hasResult = false;
  bool get hasResult => _hasResult;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      _questions = await _api.fetchQuestions();
      if (_questions.isEmpty) {
        _phase = const LoadPhase.empty();
      } else {
        _phase = LoadPhase.success(_questions);
      }
    } catch (e) {
      _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  void selectAnswer(int answerIndex) {
    _answers[_currentIndex] = answerIndex;
    notifyListeners();

    // Auto-advance after selection
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_currentIndex < totalQuestions - 1) {
        _currentIndex++;
        notifyListeners();
      } else {
        submit();
      }
    });
  }

  void goToQuestion(int index) {
    if (index >= 0 && index < totalQuestions) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  Future<void> submit() async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final answerList = _answers.entries.map((e) {
        return {
          'questionIndex': e.key,
          'selectedOption': e.value,
        };
      }).toList();

      _result = await _api.submitAnswers(answers: answerList);
      _hasResult = true;
    } catch (_) {}
    _isSubmitting = false;
    notifyListeners();
  }

  Future<void> loadResult() async {
    try {
      _result = await _api.fetchResult();
      _hasResult = true;
    } catch (_) {}
    notifyListeners();
  }
}
