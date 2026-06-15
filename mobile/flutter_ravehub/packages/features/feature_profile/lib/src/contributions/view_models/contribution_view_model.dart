import 'package:flutter/foundation.dart';
import 'package:raver_design_system/raver_design_system.dart';

import '../../profile_me/data/profile_repository.dart';

class ContributionViewModel extends ChangeNotifier {
  ContributionViewModel({required ProfileRepository repository})
      : _repository = repository;

  final ProfileRepository _repository;

  LoadPhase<Map<String, dynamic>> _phase = const LoadPhase.loading();
  LoadPhase<Map<String, dynamic>> get phase => _phase;

  Map<String, dynamic>? _data;
  Map<String, dynamic>? get data => _data;

  int get totalPoints => (_data?['totalPoints'] as int?) ?? 0;
  String get level => (_data?['level'] as String?) ?? '';
  List<dynamic> get distribution =>
      (_data?['distribution'] as List<dynamic>?) ?? [];
  List<dynamic> get history =>
      (_data?['history'] as List<dynamic>?) ?? [];

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      _data = await _repository.fetchContributions();
      _phase = LoadPhase.success(_data!);
    } catch (e) {
      _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _data = await _repository.fetchContributions();
      _phase = LoadPhase.success(_data!);
    } catch (e) {
      if (_data == null) _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }
}
