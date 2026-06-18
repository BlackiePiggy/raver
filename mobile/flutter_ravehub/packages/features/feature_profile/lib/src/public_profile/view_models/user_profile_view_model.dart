import 'package:flutter/foundation.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_models/raver_models.dart';

import '../../profile_me/data/profile_repository.dart';

class UserProfileViewModel extends ChangeNotifier {
  UserProfileViewModel({
    required this.userId,
    required ProfileRepository repository,
  }) : _repository = repository;

  final String userId;
  final ProfileRepository _repository;

  LoadPhase<UserProfile> _phase = const LoadPhase.loading();
  LoadPhase<UserProfile> get phase => _phase;
  UserProfile? _profile;
  UserProfile? get profile => _profile;

  bool _isTogglingFollow = false;
  bool get isTogglingFollow => _isTogglingFollow;

  bool get isFollowing => _profile?.isFollowing ?? false;

  // Posts
  final List<Post> _posts = [];
  List<Post> get posts => List.unmodifiable(_posts);
  int _postsPage = 1;
  int _postsTotalPages = 1;
  bool _isLoadingMorePosts = false;
  bool get isLoadingMorePosts => _isLoadingMorePosts;
  bool get canLoadMorePosts => _postsPage < _postsTotalPages;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      _profile = await _repository.fetchUserProfile(userId: userId);
      _phase = LoadPhase.success(_profile!);
      await _loadPosts();
    } catch (e) {
      _phase = LoadPhase.fromError(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _profile = await _repository.fetchUserProfile(userId: userId);
      _phase = LoadPhase.success(_profile!);
      await _loadPosts();
    } catch (e) {
      if (_profile == null) {
        _phase = LoadPhase.fromError(e);
      }
    }
    notifyListeners();
  }

  Future<void> _loadPosts() async {
    try {
      final page = await _repository.fetchUserPosts(
        userId: userId,
        page: 1,
      );
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
      final page = await _repository.fetchUserPosts(
        userId: userId,
        page: nextPage,
      );
      _posts.addAll(page.items);
      _postsPage = nextPage;
      _postsTotalPages = page.pagination?.totalPages ?? _postsTotalPages;
    } catch (_) {}
    _isLoadingMorePosts = false;
    notifyListeners();
  }

  Future<void> toggleFollow() async {
    if (_isTogglingFollow || _profile == null) return;
    _isTogglingFollow = true;
    notifyListeners();

    try {
      if (isFollowing) {
        await _repository.unfollowUser(userId: userId);
      } else {
        await _repository.followUser(userId: userId);
      }
      // Reload profile to get updated state
      _profile = await _repository.fetchUserProfile(userId: userId);
      _phase = LoadPhase.success(_profile!);
    } catch (_) {}
    _isTogglingFollow = false;
    notifyListeners();
  }

  Future<void> reportUser({required String reason}) async {
    try {
      await _repository.reportUser(userId: userId, reason: reason);
    } catch (_) {}
  }

  Future<void> blockUser() async {
    try {
      await _repository.blockUser(userId: userId);
    } catch (_) {}
  }
}
