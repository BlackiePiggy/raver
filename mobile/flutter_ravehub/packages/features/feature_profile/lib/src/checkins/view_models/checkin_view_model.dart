import 'package:flutter/foundation.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

import '../data/checkin_api.dart';

class CheckinViewModel extends ChangeNotifier {
  CheckinViewModel({required CheckinApi api}) : _api = api;

  final CheckinApi _api;

  // Overview
  LoadPhase<MyCheckinsOverviewResponse> _phase = const LoadPhase.loading();
  LoadPhase<MyCheckinsOverviewResponse> get phase => _phase;
  MyCheckinsOverviewResponse? _overview;
  MyCheckinsOverviewResponse? get overview => _overview;

  // Checkins list
  final List<WebCheckin> _checkins = [];
  List<WebCheckin> get checkins => List.unmodifiable(_checkins);
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  bool get canLoadMore => _currentPage < _totalPages;

  // View mode: 0 = timeline, 1 = gallery
  int _viewMode = 0;
  int get viewMode => _viewMode;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      _overview = await _api.fetchOverview();
      _phase = LoadPhase.success(_overview!);
      await _loadCheckins();
    } catch (e) {
      _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _overview = await _api.fetchOverview();
      _phase = LoadPhase.success(_overview!);
      await _loadCheckins();
    } catch (e) {
      if (_overview == null) _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> _loadCheckins() async {
    try {
      final page = await _api.fetchCheckins(page: 1);
      _checkins
        ..clear()
        ..addAll(page.items);
      _currentPage = 1;
      _totalPages = page.pagination?.totalPages ?? 1;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !canLoadMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final page = await _api.fetchCheckins(page: nextPage);
      _checkins.addAll(page.items);
      _currentPage = nextPage;
      _totalPages = page.pagination?.totalPages ?? _totalPages;
    } catch (_) {}
    _isLoadingMore = false;
    notifyListeners();
  }

  void setViewMode(int mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    notifyListeners();
  }
}
