import 'package:raver_models/raver_models.dart';

import 'feed_api.dart';

class FeedRepository {
  FeedRepository(this._api);

  final FeedApi _api;

  Future<FeedPage> fetchFeed({
    required int page,
    int limit = 20,
    String type = 'following',
  }) {
    return _api.fetchFeed(page: page, limit: limit, type: type);
  }

  Future<Post> createPost({
    required String text,
    List<String>? imagePaths,
    String? videoPath,
    String? eventId,
    String? location,
  }) {
    return _api.createPost(
      text: text,
      imagePaths: imagePaths,
      videoPath: videoPath,
      eventId: eventId,
      location: location,
    );
  }

  Future<Post> fetchPost({required String id}) {
    return _api.fetchPost(id: id);
  }

  Future<void> deletePost({required String id}) {
    return _api.deletePost(id: id);
  }

  Future<bool> toggleLike({
    required String postId,
    required bool currentlyLiked,
  }) async {
    if (currentlyLiked) {
      await _api.unlikePost(postId: postId);
      return false;
    } else {
      await _api.likePost(postId: postId);
      return true;
    }
  }

  Future<bool> toggleFavorite({
    required String postId,
    required bool currentlySaved,
  }) async {
    if (currentlySaved) {
      await _api.unfavoritePost(postId: postId);
      return false;
    } else {
      await _api.favoritePost(postId: postId);
      return true;
    }
  }

  Future<BFFListPage<Comment>> fetchComments({
    required String postId,
    required int page,
    int limit = 20,
  }) {
    return _api.fetchComments(postId: postId, page: page, limit: limit);
  }

  Future<Comment> postComment({
    required String postId,
    required String content,
    String? parentId,
  }) {
    return _api.postComment(
      postId: postId,
      content: content,
      parentId: parentId,
    );
  }
}
