import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:raver_design_system/raver_design_system.dart';

import '../data/quiz_api.dart';

class QuizViewModel extends ChangeNotifier {
  QuizViewModel({required QuizApi api}) : _api = api;

  final QuizApi _api;

  // Questions
  LoadPhase<List<Map<String, dynamic>>> _phase = const LoadPhase.loading();
  LoadPhase<List<Map<String, dynamic>>> get phase => _phase;

  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> get questions => _questions;

  // Current state
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;
  int get totalQuestions => _questions.length;
  String get progressText => '${_currentIndex + 1}/$totalQuestions';
  double get progress =>
      totalQuestions > 0 ? (_currentIndex + 1) / totalQuestions : 0;

  // Answers
  final Map<int, int> _answers = {};
  Map<int, int> get answers => Map.unmodifiable(_answers);

  int? get currentAnswer => _answers[_currentIndex];

  // Timer
  int _remainingSeconds = 30;
  int get remainingSeconds => _remainingSeconds;
  Timer? _timer;

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
        _startTimer();
      }
    } catch (e) {
      _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  void selectAnswer(int answerIndex) {
    _answers[_currentIndex] = answerIndex;
    notifyListeners();
  }

  void nextQuestion() {
    if (_currentIndex < totalQuestions - 1) {
      _currentIndex++;
      _resetTimer();
      notifyListeners();
    } else {
      submit();
    }
  }

  void previousQuestion() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _resetTimer();
      notifyListeners();
    }
  }

  Future<void> submit() async {
    _timer?.cancel();
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

  void _startTimer() {
    _remainingSeconds = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        nextQuestion();
      }
    });
  }

  void _resetTimer() {
    _remainingSeconds = 30;
    _timer?.cancel();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
