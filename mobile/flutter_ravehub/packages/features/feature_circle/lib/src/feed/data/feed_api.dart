import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class FeedApi {
  FeedApi(this._dio);

  final Dio _dio;

  Future<FeedPage> fetchFeed({
    String? cursor,
    required int limit,
    required String mode,
    String? eventId,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/feed',
      queryParameters: {
        'limit': limit,
        if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
        if (mode.trim().isNotEmpty) 'mode': mode,
        if (eventId != null && eventId.trim().isNotEmpty) 'eventId': eventId,
      },
    );
    return _feedPageFromPayload(response.data);
  }

  Future<void> recordFeedEvent({
    required String sessionId,
    required String eventType,
    String? postId,
    String? feedMode,
    int? position,
    Map<String, String>? metadata,
  }) async {
    await _dio.post<void>(
      '/v1/feed/events',
      data: {
        'sessionId': sessionId,
        'eventType': eventType,
        if (postId != null && postId.trim().isNotEmpty) 'postID': postId,
        if (feedMode != null && feedMode.trim().isNotEmpty)
          'feedMode': feedMode,
        if (position != null) 'position': position,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      },
    );
  }

  Future<Post?> createPost({
    required String text,
    List<String>? mediaUrls,
    String? eventId,
    String? location,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/feed/posts',
      data: {
        'content': text,
        'images': mediaUrls ?? const <String>[],
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
        if (eventId != null && eventId.trim().isNotEmpty)
          'boundEventIDs': [eventId.trim()],
      },
    );
    return _postFromCreatePayload(response.data);
  }

  Future<UploadMediaResponse> uploadPostImage({required String path}) async {
    final response = await _dio.post<dynamic>(
      '/v1/feed/upload-image',
      data: FormData.fromMap({
        'image': await MultipartFile.fromFile(path),
      }),
      options: Options(contentType: 'multipart/form-data'),
    );
    return UploadMediaResponse.fromJson(LiveApiPayload.object(response.data));
  }

  Future<UploadMediaResponse> uploadPostVideo({required String path}) async {
    final response = await _dio.post<dynamic>(
      '/v1/feed/upload-video',
      data: FormData.fromMap({
        'video': await MultipartFile.fromFile(path),
      }),
      options: Options(contentType: 'multipart/form-data'),
    );
    return UploadMediaResponse.fromJson(LiveApiPayload.object(response.data));
  }

  Future<Post> fetchPost({required String id}) async {
    final response = await _dio.get<dynamic>('/v1/feed/posts/$id');
    return Post.fromJson(LiveApiPayload.object(response.data));
  }

  Future<void> deletePost({required String id}) async {
    await _dio.delete<void>('/v1/feed/posts/$id');
  }

  Future<void> hidePost({
    required String postId,
    String reason = 'not_relevant',
  }) async {
    await _dio.post<void>(
      '/v1/feed/posts/$postId/hide',
      data: {'reason': reason},
    );
  }

  Future<void> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
    String? detail,
    String source = 'flutter_app',
  }) async {
    await _dio.post<void>(
      '/v1/reports',
      data: {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (detail != null && detail.trim().isNotEmpty) 'detail': detail.trim(),
        'source': source,
      },
    );
  }

  Future<Post> likePost({required String postId}) async {
    final response = await _dio.post<dynamic>(
      '/v1/feed/posts/$postId/like',
    );
    return Post.fromJson(LiveApiPayload.object(response.data));
  }

  Future<Post> unlikePost({required String postId}) async {
    final response = await _dio.delete<dynamic>(
      '/v1/feed/posts/$postId/like',
    );
    return Post.fromJson(LiveApiPayload.object(response.data));
  }

  Future<Post> favoritePost({required String postId}) async {
    final response = await _dio.post<dynamic>(
      '/v1/feed/posts/$postId/save',
    );
    return Post.fromJson(LiveApiPayload.object(response.data));
  }

  Future<Post> unfavoritePost({required String postId}) async {
    final response = await _dio.delete<dynamic>(
      '/v1/feed/posts/$postId/save',
    );
    return Post.fromJson(LiveApiPayload.object(response.data));
  }

  Future<Post> repostPost({required String postId}) async {
    final response = await _dio.post<dynamic>(
      '/v1/feed/posts/$postId/repost',
    );
    return Post.fromJson(LiveApiPayload.object(response.data));
  }

  Future<Post> unrepostPost({required String postId}) async {
    final response = await _dio.delete<dynamic>(
      '/v1/feed/posts/$postId/repost',
    );
    return Post.fromJson(LiveApiPayload.object(response.data));
  }

  Future<Post> sharePost({
    required String postId,
    required String channel,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/feed/posts/$postId/share',
      data: {'channel': channel, 'status': 'completed'},
    );
    return Post.fromJson(LiveApiPayload.object(response.data));
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
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/share-links/resolve',
      data: {
        'targetType': targetType,
        'targetId': targetId,
        'channel': channel,
        'targetSeed': {
          'title': title,
          if (subtitle != null && subtitle.isNotEmpty) 'subtitle': subtitle,
          if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
          if (canonicalUrl != null && canonicalUrl.isNotEmpty)
            'canonicalUrl': canonicalUrl,
          if (deepLink != null && deepLink.isNotEmpty) 'deepLink': deepLink,
          if (fallbackUrl != null && fallbackUrl.isNotEmpty)
            'fallbackUrl': fallbackUrl,
          'previewType': 'content_card',
          'visibility': 'public',
        },
      },
    );
    return ShareLinkPayload.fromJson(LiveApiPayload.object(response.data));
  }

  Future<BFFListPage<Comment>> fetchComments({
    required String postId,
    required int page,
    required int limit,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/feed/posts/$postId/comments',
      queryParameters: {'page': page, 'limit': limit},
    );
    return _commentPageFromPayload(response.data);
  }

  Future<Comment> postComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/feed/posts/$postId/comments',
      data: {'content': content, if (parentId != null) 'parentId': parentId},
    );
    return Comment.fromJson(LiveApiPayload.object(response.data));
  }
}

BFFListPage<Comment> _commentPageFromPayload(Object? payload) {
  return LiveApiPayload.listPage<Comment>(
    payload,
    Comment.fromJson,
    itemKeys: const ['comments', 'items', 'list', 'data'],
  );
}

FeedPage _feedPageFromPayload(Object? payload) {
  final items = LiveApiPayload.items(
    payload,
    itemKeys: const ['posts', 'items', 'list', 'data'],
  );
  final posts =
      items.whereType<Map<String, dynamic>>().map(Post.fromJson).toList();
  return FeedPage(
    posts: posts,
    nextCursor: LiveApiPayload.cursor(payload),
  );
}

Post? _postFromCreatePayload(Object? payload) {
  final root = payload is Map<String, dynamic> ? payload : const {};
  final object = LiveApiPayload.object(payload);
  final status = (object['status'] ?? root['status'])?.toString();
  final action = (object['action'] ?? root['action'])?.toString();
  if (status == 'submitted_for_review' || action == 'submitted_for_review') {
    return null;
  }
  if (object['id'] != null &&
      object['content'] != null &&
      (object['user'] != null || object['author'] != null)) {
    return Post.fromJson(object);
  }
  return null;
}
