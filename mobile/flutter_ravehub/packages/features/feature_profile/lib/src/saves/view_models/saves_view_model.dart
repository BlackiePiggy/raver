import 'package:flutter/foundation.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

import '../../profile_me/data/profile_repository.dart';

class SavesViewModel extends ChangeNotifier {
  SavesViewModel({required ProfileRepository repository})
      : _repository = repository;

  final ProfileRepository _repository;

  // Tabs: event, dj, set, post
  int _selectedTab = 0;
  int get selectedTab => _selectedTab;

  static const _typeFilters = ['event', 'dj', 'set', 'post'];

  LoadPhase<List<Post>> _phase = const LoadPhase.loading();
  LoadPhase<List<Post>> get phase => _phase;

  final List<Post> _saves = [];
  List<Post> get saves => List.unmodifiable(_saves);

  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  bool get canLoadMore => _currentPage < _totalPages;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      final page = await _repository.fetchMySaves(
        page: 1,
        type: _typeFilters[_selectedTab],
      );
      _saves
        ..clear()
        ..addAll(page.items);
      _currentPage = 1;
      _totalPages = page.pagination?.totalPages ?? 1;
      _phase = _saves.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_saves);
    } catch (e) {
      _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final page = await _repository.fetchMySaves(
        page: 1,
        type: _typeFilters[_selectedTab],
      );
      _saves
        ..clear()
        ..addAll(page.items);
      _currentPage = 1;
      _totalPages = page.pagination?.totalPages ?? 1;
      _phase = _saves.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_saves);
    } catch (e) {
      if (_saves.isEmpty) _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !canLoadMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final page = await _repository.fetchMySaves(
        page: nextPage,
        type: _typeFilters[_selectedTab],
      );
      _saves.addAll(page.items);
      _currentPage = nextPage;
      _totalPages = page.pagination?.totalPages ?? _totalPages;
      _phase = LoadPhase.success(_saves);
    } catch (_) {}
    _isLoadingMore = false;
    notifyListeners();
  }

  void setSelectedTab(int index) {
    if (_selectedTab == index) return;
    _selectedTab = index;
    load();
  }
}
