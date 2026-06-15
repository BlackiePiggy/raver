import 'package:flutter/foundation.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_design_system/raver_design_system.dart';

import '../../data/feed_repository.dart';

class PostDetailViewModel extends ChangeNotifier {
  PostDetailViewModel({
    required this.postId,
    required FeedRepository repository,
  }) : _repository = repository;

  final String postId;
  final FeedRepository _repository;

  LoadPhase<Post> _phase = const LoadPhase.loading();
  LoadPhase<Post> get phase => _phase;

  Post? _post;
  Post? get post => _post;

  final List<Comment> _comments = [];
  List<Comment> get comments => List.unmodifiable(_comments);

  int _commentPage = 1;
  int _commentTotalPages = 1;
  bool _isLoadingComments = false;
  bool get isLoadingComments => _isLoadingComments;
  bool get canLoadMoreComments => _commentPage < _commentTotalPages;

  bool _isSendingComment = false;
  bool get isSendingComment => _isSendingComment;

  Future<void> load() async {
    _phase = const LoadPhase.loading();
    notifyListeners();

    try {
      _post = await _repository.fetchPost(id: postId);
      _phase = LoadPhase.success(_post!);
      _loadComments();
    } catch (e) {
      _phase = LoadPhase.failure(e);
    }
    notifyListeners();
  }

  Future<void> _loadComments() async {
    _isLoadingComments = true;
    try {
      final page = await _repository.fetchComments(
        postId: postId,
        page: 1,
      );
      _comments
        ..clear()
        ..addAll(page.items);
      _commentPage = 1;
      _commentTotalPages = page.pagination?.totalPages ?? 1;
    } catch (_) {
      // Silently fail; comments are secondary content.
    }
    _isLoadingComments = false;
    notifyListeners();
  }

  Future<void> loadMoreComments() async {
    if (_isLoadingComments || !canLoadMoreComments) return;
    _isLoadingComments = true;
    notifyListeners();

    try {
      final nextPage = _commentPage + 1;
      final page = await _repository.fetchComments(
        postId: postId,
        page: nextPage,
      );
      _comments.addAll(page.items);
      _commentPage = nextPage;
      _commentTotalPages = page.pagination?.totalPages ?? _commentTotalPages;
    } catch (_) {
      // Silently fail.
    }
    _isLoadingComments = false;
    notifyListeners();
  }

  Future<bool> sendComment(String content, {String? parentId}) async {
    if (_isSendingComment || content.trim().isEmpty) return false;
    _isSendingComment = true;
    notifyListeners();

    try {
      final comment = await _repository.postComment(
        postId: postId,
        content: content.trim(),
        parentId: parentId,
      );
      _comments.insert(0, comment);
      _isSendingComment = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isSendingComment = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleLike() async {
    if (_post == null) return;
    final wasLiked = _post!.isLiked ?? false;

    _post = Post(
      id: _post!.id,
      content: _post!.content,
      images: _post!.images,
      videos: _post!.videos,
      user: _post!.user,
      likeCount: _post!.likeCount + (wasLiked ? -1 : 1),
      commentCount: _post!.commentCount,
      repostCount: _post!.repostCount,
      saveCount: _post!.saveCount,
      shareCount: _post!.shareCount,
      isLiked: !wasLiked,
      isReposted: _post!.isReposted,
      isSaved: _post!.isSaved,
      eventId: _post!.eventId,
      eventName: _post!.eventName,
      squad: _post!.squad,
      createdAt: _post!.createdAt,
    );
    _phase = LoadPhase.success(_post!);
    notifyListeners();

    try {
      await _repository.toggleLike(
        postId: _post!.id,
        currentlyLiked: wasLiked,
      );
    } catch (_) {
      // Revert optimistic update already shown; not critical.
    }
  }
}
