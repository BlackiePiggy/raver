import 'package:flutter/foundation.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

import '../data/follow_api.dart';

class FollowListViewModel extends ChangeNotifier {
  FollowListViewModel({
    required FollowApi api,
    required this.userId,
    required this.listType,
  }) : _api = api;

  final FollowApi _api;
  final String userId;
  final String listType; // 'following' or 'followers'

  LoadPhase<List<UserSummary>> _phase = const LoadPhase.loading();
  LoadPhase<List<UserSummary>> get phase => _phase;

  final List<UserSummary> _users = [];
  List<UserSummary> get users => List.unmodifiable(_users);

  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  bool get canLoadMore => _currentPage < _totalPages;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      final page = listType == 'followers'
          ? await _api.fetchFollowers(userId: userId, page: 1)
          : await _api.fetchFollowing(userId: userId, page: 1);

      _users
        ..clear()
        ..addAll(page.items);
      _currentPage = 1;
      _totalPages = page.pagination?.totalPages ?? 1;
      _phase = _users.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_users);
    } catch (e) {
      _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final page = listType == 'followers'
          ? await _api.fetchFollowers(userId: userId, page: 1)
          : await _api.fetchFollowing(userId: userId, page: 1);

      _users
        ..clear()
        ..addAll(page.items);
      _currentPage = 1;
      _totalPages = page.pagination?.totalPages ?? 1;
      _phase = _users.isEmpty
          ? const LoadPhase.empty()
          : LoadPhase.success(_users);
    } catch (e) {
      if (_users.isEmpty) _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !canLoadMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final page = listType == 'followers'
          ? await _api.fetchFollowers(userId: userId, page: nextPage)
          : await _api.fetchFollowing(userId: userId, page: nextPage);

      _users.addAll(page.items);
      _currentPage = nextPage;
      _totalPages = page.pagination?.totalPages ?? _totalPages;
      _phase = LoadPhase.success(_users);
    } catch (_) {}
    _isLoadingMore = false;
    notifyListeners();
  }
}
