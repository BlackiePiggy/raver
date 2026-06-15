import 'package:flutter/foundation.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

import '../data/publishes_api.dart';

class PublishesViewModel extends ChangeNotifier {
  PublishesViewModel({required PublishesApi api}) : _api = api;

  final PublishesApi _api;

  // Phase for the list
  LoadPhase<List<ContentSubmissionSummary>> _phase =
      const LoadPhase.loading();
  LoadPhase<List<ContentSubmissionSummary>> get phase => _phase;

  final List<ContentSubmissionSummary> _submissions = [];
  List<ContentSubmissionSummary> get submissions =>
      List.unmodifiable(_submissions);

  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  bool get canLoadMore => _currentPage < _totalPages;

  // Tab filter: event/dj/set/news
  int _selectedTab = 0;
  int get selectedTab => _selectedTab;

  static const _typeFilters = ['event', 'dj', 'set', 'news'];

  // Detail
  ContentSubmissionDetail? _detail;
  ContentSubmissionDetail? get detail => _detail;
  bool _isLoadingDetail = false;
  bool get isLoadingDetail => _isLoadingDetail;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      final page = await _api.fetchSubmissions(
        page: 1,
        type: _typeFilters[_selectedTab],
      );
      _submissions
        ..clear()
        ..addAll(page.items);
      _currentPage = 1;
      _totalPages = page.pagination?.totalPages ?? 1;
      _phase = _submissions.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_submissions);
    } catch (e) {
      _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final page = await _api.fetchSubmissions(
        page: 1,
        type: _typeFilters[_selectedTab],
      );
      _submissions
        ..clear()
        ..addAll(page.items);
      _currentPage = 1;
      _totalPages = page.pagination?.totalPages ?? 1;
      _phase = _submissions.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_submissions);
    } catch (e) {
      if (_submissions.isEmpty) _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !canLoadMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final page = await _api.fetchSubmissions(
        page: nextPage,
        type: _typeFilters[_selectedTab],
      );
      _submissions.addAll(page.items);
      _currentPage = nextPage;
      _totalPages = page.pagination?.totalPages ?? _totalPages;
      _phase = LoadPhase.success(_submissions);
    } catch (_) {}
    _isLoadingMore = false;
    notifyListeners();
  }

  void setSelectedTab(int index) {
    if (_selectedTab == index) return;
    _selectedTab = index;
    load();
  }

  Future<void> loadDetail(String id) async {
    _isLoadingDetail = true;
    _detail = null;
    notifyListeners();

    try {
      _detail = await _api.fetchSubmissionDetail(id: id);
    } catch (_) {}
    _isLoadingDetail = false;
    notifyListeners();
  }
}
