import 'package:raver_models/raver_models.dart';

import 'feed_api.dart';

class FeedRepository {
  FeedRepository(this._api);

  final FeedApi _api;

  Future<FeedPage> fetchFeed({
    String? cursor,
    int limit = 12,
    String mode = 'recommended',
    String? eventId,
  }) {
    return _api.fetchFeed(
      cursor: cursor,
      limit: limit,
      mode: mode,
      eventId: eventId,
    );
  }

  Future<void> recordFeedEvent({
    required String sessionId,
    required String eventType,
    String? postId,
    String? feedMode,
    int? position,
    Map<String, String>? metadata,
  }) {
    return _api.recordFeedEvent(
      sessionId: sessionId,
      eventType: eventType,
      postId: postId,
      feedMode: feedMode,
      position: position,
      metadata: metadata,
    );
  }

  Future<Post?> createPost({
    required String text,
    List<String>? mediaUrls,
    String? eventId,
    String? location,
  }) {
    return _api.createPost(
      text: text,
      mediaUrls: mediaUrls,
      eventId: eventId,
      location: location,
    );
  }

  Future<UploadMediaResponse> uploadPostImage({required String path}) {
    return _api.uploadPostImage(path: path);
  }

  Future<UploadMediaResponse> uploadPostVideo({required String path}) {
    return _api.uploadPostVideo(path: path);
  }

  Future<Post> fetchPost({required String id}) {
    return _api.fetchPost(id: id);
  }

  Future<void> deletePost({required String id}) {
    return _api.deletePost(id: id);
  }

  Future<void> hidePost({
    required String postId,
    String reason = 'not_relevant',
  }) {
    return _api.hidePost(postId: postId, reason: reason);
  }

  Future<void> reportPost({
    required String postId,
    required String reason,
    String? detail,
  }) {
    return _api.reportContent(
      targetType: 'post',
      targetId: postId,
      reason: reason,
      detail: detail,
      source: 'flutter_app',
    );
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

  Future<Post> toggleLikePost({
    required String postId,
    required bool currentlyLiked,
  }) {
    return currentlyLiked
        ? _api.unlikePost(postId: postId)
        : _api.likePost(postId: postId);
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

  Future<Post> toggleFavoritePost({
    required String postId,
    required bool currentlySaved,
  }) {
    return currentlySaved
        ? _api.unfavoritePost(postId: postId)
        : _api.favoritePost(postId: postId);
  }

  Future<Post> toggleRepost({
    required String postId,
    required bool currentlyReposted,
  }) {
    return currentlyReposted
        ? _api.unrepostPost(postId: postId)
        : _api.repostPost(postId: postId);
  }

  Future<Post> sharePost({
    required String postId,
    String channel = 'copy_link',
  }) {
    return _api.sharePost(postId: postId, channel: channel);
  }

  Future<String> resolvePostShareUrl({
    required Post post,
    String channel = 'system_share',
  }) async {
    final fallbackUrl = 'https://ravehub.top/circle/post/${post.id}';
    final payload = await resolveShareLink(
      targetType: 'post',
      targetId: post.id,
      title: post.content.isNotEmpty ? post.content : post.user.displayName,
      subtitle: post.user.displayName,
      imageUrl: post.images?.isNotEmpty == true ? post.images!.first : null,
      canonicalUrl: fallbackUrl,
      deepLink: 'raver://post/${post.id}',
      fallbackUrl: fallbackUrl,
      channel: channel,
    );
    if (payload.shortUrl.isNotEmpty) return payload.shortUrl;
    if (payload.url.isNotEmpty) return payload.url;
    return fallbackUrl;
  }

  Future<ShareLinkPayload> resolveShareLink({
    required String targetType,
    required String targetId,
    required String title,
    String? subtitle,
    String? imageUrl,
    String? canonicalUrl,
    String? deepLink,
    String? fallbackUrl,
    String channel = 'copy_link',
  }) {
    return _api.resolveShareLink(
      targetType: targetType,
      targetId: targetId,
      title: title,
      subtitle: subtitle,
      imageUrl: imageUrl,
      canonicalUrl: canonicalUrl,
      deepLink: deepLink,
      fallbackUrl: fallbackUrl,
      channel: channel,
    );
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
