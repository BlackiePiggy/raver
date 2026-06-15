import 'package:flutter/foundation.dart';
import 'package:raver_design_system/raver_design_system.dart';

import '../../data/circle_id_api.dart';
import '../../data/circle_id_repository.dart';

class CircleIdViewModel extends ChangeNotifier {
  CircleIdViewModel({required CircleIdRepository repository})
      : _repository = repository;

  final CircleIdRepository _repository;

  LoadPhase<List<CircleIdCard>> _phase = const LoadPhase.loading();
  LoadPhase<List<CircleIdCard>> get phase => _phase;

  final List<CircleIdCard> _cards = [];
  List<CircleIdCard> get cards => List.unmodifiable(_cards);

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      _cards
        ..clear()
        ..addAll(await _repository.fetchMyCircleIds());
      _phase = _cards.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_cards);
    } catch (e) {
      _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _cards
        ..clear()
        ..addAll(await _repository.fetchMyCircleIds());
      _phase = _cards.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_cards);
    } catch (e) {
      if (_cards.isEmpty) {
        _phase = LoadPhase.failure(e);
      }
    }
    notifyListeners();
  }

  Future<CircleIdCard?> createCard({
    required String nickname,
    required String tagline,
    required int gradientIndex,
  }) async {
    try {
      final card = await _repository.createCircleId(
        nickname: nickname,
        tagline: tagline,
        gradientIndex: gradientIndex,
      );
      _cards.insert(0, card);
      _phase = LoadPhase.success(_cards);
      notifyListeners();
      return card;
    } catch (_) {
      return null;
    }
  }

  Future<CircleIdCard?> updateCard({
    required String id,
    String? nickname,
    String? tagline,
    int? gradientIndex,
  }) async {
    try {
      final updated = await _repository.updateCircleId(
        id: id,
        nickname: nickname,
        tagline: tagline,
        gradientIndex: gradientIndex,
      );
      final index = _cards.indexWhere((c) => c.id == id);
      if (index != -1) {
        _cards[index] = updated;
        _phase = LoadPhase.success(_cards);
        notifyListeners();
      }
      return updated;
    } catch (_) {
      return null;
    }
  }
}
