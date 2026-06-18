import 'package:flutter/foundation.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

import '../../data/profile_repository.dart';

class ProfileMeViewModel extends ChangeNotifier {
  ProfileMeViewModel({required ProfileRepository repository})
      : _repository = repository;

  final ProfileRepository _repository;

  // Profile
  LoadPhase<UserProfile> _phase = const LoadPhase.loading();
  LoadPhase<UserProfile> get phase => _phase;
  UserProfile? _profile;
  UserProfile? get profile => _profile;

  // Posts
  final List<Post> _posts = [];
  List<Post> get posts => List.unmodifiable(_posts);
  int _postsPage = 1;
  int _postsTotalPages = 1;
  bool _isLoadingMorePosts = false;
  bool get isLoadingMorePosts => _isLoadingMorePosts;
  bool get canLoadMorePosts => _postsPage < _postsTotalPages;

  // Saves
  final List<Post> _saves = [];
  List<Post> get saves => List.unmodifiable(_saves);
  int _savesPage = 1;
  int _savesTotalPages = 1;
  bool _isLoadingMoreSaves = false;
  bool get isLoadingMoreSaves => _isLoadingMoreSaves;
  bool get canLoadMoreSaves => _savesPage < _savesTotalPages;

  // Tabs
  int _selectedTab = 0;
  int get selectedTab => _selectedTab;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      _profile = await _repository.fetchMe();
      _phase = LoadPhase.success(_profile!);
      // Load initial posts
      await _loadPosts();
    } catch (e) {
      _phase = LoadPhase.fromError(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _profile = await _repository.fetchMe();
      _phase = LoadPhase.success(_profile!);
      if (_selectedTab == 0) {
        await _loadPosts();
      } else if (_selectedTab == 1) {
        await _loadSaves();
      }
    } catch (e) {
      if (_profile == null) {
        _phase = LoadPhase.fromError(e);
      }
    }
    notifyListeners();
  }

  void setSelectedTab(int index) {
    if (_selectedTab == index) return;
    _selectedTab = index;
    notifyListeners();

    if (index == 0 && _posts.isEmpty) {
      _loadPosts();
    } else if (index == 1 && _saves.isEmpty) {
      _loadSaves();
    }
  }

  Future<void> _loadPosts() async {
    try {
      final page = await _repository.fetchMyPosts(page: 1);
      _posts
        ..clear()
        ..addAll(page.items);
      _postsPage = 1;
      _postsTotalPages = page.pagination?.totalPages ?? 1;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> loadMorePosts() async {
    if (_isLoadingMorePosts || !canLoadMorePosts) return;
    _isLoadingMorePosts = true;
    notifyListeners();

    try {
      final nextPage = _postsPage + 1;
      final page = await _repository.fetchMyPosts(page: nextPage);
      _posts.addAll(page.items);
      _postsPage = nextPage;
      _postsTotalPages = page.pagination?.totalPages ?? _postsTotalPages;
    } catch (_) {}
    _isLoadingMorePosts = false;
    notifyListeners();
  }

  Future<void> _loadSaves() async {
    try {
      final page = await _repository.fetchMySaves(page: 1);
      _saves
        ..clear()
        ..addAll(page.items);
      _savesPage = 1;
      _savesTotalPages = page.pagination?.totalPages ?? 1;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> loadMoreSaves() async {
    if (_isLoadingMoreSaves || !canLoadMoreSaves) return;
    _isLoadingMoreSaves = true;
    notifyListeners();

    try {
      final nextPage = _savesPage + 1;
      final page = await _repository.fetchMySaves(page: nextPage);
      _saves.addAll(page.items);
      _savesPage = nextPage;
      _savesTotalPages = page.pagination?.totalPages ?? _savesTotalPages;
    } catch (_) {}
    _isLoadingMoreSaves = false;
    notifyListeners();
  }
}
