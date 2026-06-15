import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class FeedApi {
  FeedApi(this._dio);

  final Dio _dio;

  Future<FeedPage> fetchFeed({
    required int page,
    required int limit,
    required String type,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/feed',
      queryParameters: {
        'page': page,
        'limit': limit,
        'type': type,
      },
    );
    return FeedPage.fromJson(response.data!);
  }

  Future<Post> createPost({
    required String text,
    List<String>? imagePaths,
    String? videoPath,
    String? eventId,
    String? location,
  }) async {
    final formData = FormData.fromMap({
      'text': text,
      if (eventId != null) 'eventId': eventId,
      if (location != null) 'location': location,
    });

    if (imagePaths != null) {
      for (final path in imagePaths) {
        formData.files.add(
          MapEntry(
            'images',
            await MultipartFile.fromFile(path),
          ),
        );
      }
    }

    if (videoPath != null) {
      formData.files.add(
        MapEntry(
          'video',
          await MultipartFile.fromFile(videoPath),
        ),
      );
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/social/posts',
      data: formData,
    );
    return Post.fromJson(response.data!);
  }

  Future<Post> fetchPost({required String id}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/posts/$id',
    );
    return Post.fromJson(response.data!);
  }

  Future<void> deletePost({required String id}) async {
    await _dio.delete<void>('/v1/social/posts/$id');
  }

  Future<void> likePost({required String postId}) async {
    await _dio.post<void>('/v1/social/posts/$postId/like');
  }

  Future<void> unlikePost({required String postId}) async {
    await _dio.delete<void>('/v1/social/posts/$postId/like');
  }

  Future<void> favoritePost({required String postId}) async {
    await _dio.post<void>('/v1/social/posts/$postId/favorite');
  }

  Future<void> unfavoritePost({required String postId}) async {
    await _dio.delete<void>('/v1/social/posts/$postId/favorite');
  }

  Future<BFFListPage<Comment>> fetchComments({
    required String postId,
    required int page,
    required int limit,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/social/posts/$postId/comments',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    return BFFListPage.fromJson(
      response.data!,
      (json) => Comment.fromJson(json! as Map<String, dynamic>),
    );
  }

  Future<Comment> postComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/social/posts/$postId/comments',
      data: {
        'content': content,
        if (parentId != null) 'parentId': parentId,
      },
    );
    return Comment.fromJson(response.data!);
  }
}
