import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_design_system/raver_design_system.dart';

import '../../data/feed_repository.dart';

enum FeedType { recommended, following, latest }

extension FeedTypeApiValue on FeedType {
  String get apiValue => switch (this) {
        FeedType.recommended => 'recommended',
        FeedType.following => 'following',
        FeedType.latest => 'latest',
      };
}

class FeedViewModel extends ChangeNotifier {
  FeedViewModel({required FeedRepository repository})
      : _repository = repository,
        _feedSessionId = 'flutter-${DateTime.now().microsecondsSinceEpoch}';

  final FeedRepository _repository;
  final String _feedSessionId;

  LoadPhase<List<Post>> _phase = const LoadPhase.loading();
  LoadPhase<List<Post>> get phase => _phase;

  final List<Post> _posts = [];
  List<Post> get posts => List.unmodifiable(_posts);

  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  bool get canLoadMore => _hasMore;

  FeedType _feedType = FeedType.recommended;
  FeedType get feedType => _feedType;

  final Set<String> _localHiddenPostIds = {};
  final Set<String> _reportedImpressionPostIds = {};

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      final page = await _repository.fetchFeed(
        cursor: null,
        mode: _feedType.apiValue,
      );
      _posts
        ..clear()
        ..addAll(_filterVisiblePosts(page.posts));
      _nextCursor = page.nextCursor;
      _hasMore = _nextCursor != null;
      _phase =
          _posts.isEmpty ? const LoadPhase.empty() : LoadPhase.success(_posts);
    } catch (e) {
      _phase = LoadPhase.fromError(e);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final page = await _repository.fetchFeed(
        cursor: null,
        mode: _feedType.apiValue,
      );
      _posts
        ..clear()
        ..addAll(_filterVisiblePosts(page.posts));
      _nextCursor = page.nextCursor;
      _hasMore = _nextCursor != null;
      _phase =
          _posts.isEmpty ? const LoadPhase.empty() : LoadPhase.success(_posts);
    } catch (e) {
      if (_posts.isEmpty) {
        _phase = LoadPhase.fromError(e);
      }
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final cursor = _nextCursor;
    if (cursor == null || cursor.trim().isEmpty) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _repository.fetchFeed(
        cursor: cursor,
        mode: _feedType.apiValue,
      );
      final existingIds = _posts.map((post) => post.id).toSet();
      _posts.addAll(
        _filterVisiblePosts(
          page.posts.where((post) => !existingIds.contains(post.id)),
        ),
      );
      _nextCursor = page.nextCursor;
      _hasMore = _nextCursor != null;
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

    _posts[index] = post.copyWith(
      likeCount: post.likeCount + (wasLiked ? -1 : 1),
      isLiked: !wasLiked,
    );
    notifyListeners();

    try {
      await _repository.toggleLike(
        postId: post.id,
        currentlyLiked: wasLiked,
      );
      await _safeRecordFeedEvent(
        eventType: 'feed_like',
        postId: post.id,
        position: index,
      );
    } catch (_) {
      _posts[index] = post;
      notifyListeners();
    }
  }

  Future<void> toggleSave(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    final wasSaved = post.isSaved ?? false;

    _posts[index] = post.copyWith(
      saveCount: post.saveCount + (wasSaved ? -1 : 1),
      isSaved: !wasSaved,
    );
    notifyListeners();

    try {
      await _repository.toggleFavorite(
        postId: post.id,
        currentlySaved: wasSaved,
      );
      await _safeRecordFeedEvent(
        eventType: 'feed_save',
        postId: post.id,
        position: index,
      );
    } catch (_) {
      _posts[index] = post;
      notifyListeners();
    }
  }

  Future<String> resolveShareUrl(int index) {
    if (index < 0 || index >= _posts.length) {
      return Future.value('https://ravehub.top');
    }
    return _repository.resolvePostShareUrl(
      post: _posts[index],
      channel: 'system_share',
    );
  }

  Future<void> reportShare(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    try {
      final updated = await _repository.sharePost(
        postId: post.id,
        channel: 'system_share',
      );
      _posts[index] = updated;
      notifyListeners();
      await _safeRecordFeedEvent(
        eventType: 'feed_share',
        postId: post.id,
        position: index,
        metadata: {'channel': 'system_share'},
      );
    } catch (_) {
      _posts[index] = post.copyWith(shareCount: post.shareCount + 1);
      notifyListeners();
    }
  }

  Future<bool> hidePost(
    int index, {
    String reason = 'not_relevant',
  }) async {
    if (index < 0 || index >= _posts.length) return false;
    final removed = _posts.removeAt(index);
    _localHiddenPostIds.add(removed.id);
    _phase =
        _posts.isEmpty ? const LoadPhase.empty() : LoadPhase.success(_posts);
    notifyListeners();

    try {
      await _repository.hidePost(postId: removed.id, reason: reason);
      await _safeRecordFeedEvent(
        eventType: 'feed_hide',
        postId: removed.id,
        position: index,
        metadata: {'reason': reason},
      );
      return true;
    } catch (_) {
      _localHiddenPostIds.remove(removed.id);
      final restoreIndex = index > _posts.length ? _posts.length : index;
      _posts.insert(restoreIndex < 0 ? 0 : restoreIndex, removed);
      _phase = LoadPhase.success(_posts);
      notifyListeners();
      return false;
    }
  }

  void trackImpressionIfNeeded(int index) {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    if (!_reportedImpressionPostIds.add(post.id)) return;
    _safeRecordFeedEvent(
      eventType: 'feed_impression',
      postId: post.id,
      position: index,
      metadata: {'source': 'feed_card'},
    );
  }

  void trackOpenPost(int index) {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    _safeRecordFeedEvent(
      eventType: 'feed_open_post',
      postId: post.id,
      position: index,
      metadata: {'source': 'feed_card_tap'},
    );
  }

  Future<bool> reportPost(
    int index, {
    required String reason,
    String? detail,
  }) async {
    if (index < 0 || index >= _posts.length) return false;
    try {
      await _repository.reportPost(
        postId: _posts[index].id,
        reason: reason,
        detail: detail,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  List<Post> _filterVisiblePosts(Iterable<Post> posts) {
    return posts
        .where((post) => !_localHiddenPostIds.contains(post.id))
        .toList();
  }

  Future<void> _safeRecordFeedEvent({
    required String eventType,
    String? postId,
    int? position,
    Map<String, String>? metadata,
  }) async {
    try {
      await _repository.recordFeedEvent(
        sessionId: _feedSessionId,
        eventType: eventType,
        postId: postId,
        feedMode: _feedType.apiValue,
        position: position,
        metadata: metadata,
      );
    } catch (_) {
      // Analytics failures must not block feed interactions.
    }
  }
}
