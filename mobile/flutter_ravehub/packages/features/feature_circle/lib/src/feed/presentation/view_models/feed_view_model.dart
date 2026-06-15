import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_design_system/raver_design_system.dart';

import '../../data/feed_repository.dart';

enum FeedType { following, recommended }

class FeedViewModel extends ChangeNotifier {
  FeedViewModel({required FeedRepository repository})
      : _repository = repository;

  final FeedRepository _repository;

  LoadPhase<List<Post>> _phase = const LoadPhase.loading();
  LoadPhase<List<Post>> get phase => _phase;

  final List<Post> _posts = [];
  List<Post> get posts => List.unmodifiable(_posts);

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  bool get canLoadMore => _hasMore;

  FeedType _feedType = FeedType.following;
  FeedType get feedType => _feedType;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      final page = await _repository.fetchFeed(
        page: 1,
        type: _feedType == FeedType.following ? 'following' : 'recommended',
      );
      _posts
        ..clear()
        ..addAll(page.posts);
      _currentPage = 1;
      _hasMore = page.nextCursor != null;
      _phase =
          _posts.isEmpty ? const LoadPhase.empty() : LoadPhase.success(_posts);
    } catch (e) {
      _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final page = await _repository.fetchFeed(
        page: 1,
        type: _feedType == FeedType.following ? 'following' : 'recommended',
      );
      _posts
        ..clear()
        ..addAll(page.posts);
      _currentPage = 1;
      _hasMore = page.nextCursor != null;
      _phase =
          _posts.isEmpty ? const LoadPhase.empty() : LoadPhase.success(_posts);
    } catch (e) {
      if (_posts.isEmpty) {
        _phase = LoadPhase.failure(e);
      }
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final page = await _repository.fetchFeed(
        page: nextPage,
        type: _feedType == FeedType.following ? 'following' : 'recommended',
      );
      _posts.addAll(page.posts);
      _currentPage = nextPage;
      _hasMore = page.nextCursor != null;
      _phase = LoadPhase.success(_posts);
    } catch (_) {
      // Silently fail on pagination; user can scroll again to retry.
    }
    _isLoadingMore = false;
    notifyListeners();
  }

  void setFeedType(FeedType type) {
    if (_feedType == type) return;
    _feedType = type;
    load();
  }

  Future<void> toggleLike(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    final wasLiked = post.isLiked ?? false;

    // Optimistic update
    _posts[index] = Post(
      id: post.id,
      content: post.content,
      images: post.images,
      videos: post.videos,
      user: post.user,
      likeCount: post.likeCount + (wasLiked ? -1 : 1),
      commentCount: post.commentCount,
      repostCount: post.repostCount,
      saveCount: post.saveCount,
      shareCount: post.shareCount,
      isLiked: !wasLiked,
      isReposted: post.isReposted,
      isSaved: post.isSaved,
      eventId: post.eventId,
      eventName: post.eventName,
      squad: post.squad,
      createdAt: post.createdAt,
    );
    notifyListeners();

    try {
      await _repository.toggleLike(
        postId: post.id,
        currentlyLiked: wasLiked,
      );
    } catch (_) {
      // Revert on failure
      _posts[index] = post;
      notifyListeners();
    }
  }

  Future<void> toggleSave(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    final wasSaved = post.isSaved ?? false;

    _posts[index] = Post(
      id: post.id,
      content: post.content,
      images: post.images,
      videos: post.videos,
      user: post.user,
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      repostCount: post.repostCount,
      saveCount: post.saveCount + (wasSaved ? -1 : 1),
      shareCount: post.shareCount,
      isLiked: post.isLiked,
      isReposted: post.isReposted,
      isSaved: !wasSaved,
      eventId: post.eventId,
      eventName: post.eventName,
      squad: post.squad,
      createdAt: post.createdAt,
    );
    notifyListeners();

    try {
      await _repository.toggleFavorite(
        postId: post.id,
        currentlySaved: wasSaved,
      );
    } catch (_) {
      _posts[index] = post;
      notifyListeners();
    }
  }
}
