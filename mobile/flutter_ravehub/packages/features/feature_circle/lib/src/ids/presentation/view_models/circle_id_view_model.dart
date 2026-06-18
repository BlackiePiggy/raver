import 'package:flutter/foundation.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

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
      _phase =
          _cards.isEmpty ? const LoadPhase.empty() : LoadPhase.success(_cards);
    } catch (e) {
      _phase = LoadPhase.fromError(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _cards
        ..clear()
        ..addAll(await _repository.fetchMyCircleIds());
      _phase =
          _cards.isEmpty ? const LoadPhase.empty() : LoadPhase.success(_cards);
    } catch (e) {
      if (_cards.isEmpty) {
        _phase = LoadPhase.fromError(e);
      }
    }
    notifyListeners();
  }

  Future<List<WebEvent>> searchEvents({String? search}) {
    return _repository.searchEvents(search: search);
  }

  Future<List<WebDJ>> searchDjs({String? search}) {
    return _repository.searchDjs(search: search);
  }

  Future<CircleIdCard?> createCard(CircleIdCreationDraft draft) async {
    try {
      final card = await _repository.createCircleId(draft);
      _cards.insert(0, card);
      _phase = LoadPhase.success(_cards);
      notifyListeners();
      return card;
    } catch (_) {
      return null;
    }
  }

  void replaceCard(CircleIdCard card) {
    final index = _cards.indexWhere((item) => item.id == card.id);
    if (index == -1) return;
    _cards[index] = card;
    _phase = LoadPhase.success(_cards);
    notifyListeners();
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
