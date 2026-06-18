import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_network/raver_network.dart';

class SetApi {
  final Dio _dio;

  SetApi(this._dio);

  Future<BFFListPage<WebDJSet>> fetchSets({
    int page = 1,
    int limit = 20,
    String sortBy = 'latest',
    String? djId,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/dj-sets',
      queryParameters: {
        'page': page,
        'limit': limit,
        'sortBy': sortBy,
        if (djId != null) 'djId': djId,
      },
    );
    return BFFListPage(
      items: LiveApiPayload.items(response.data)
          .whereType<Map<String, dynamic>>()
          .map(WebDJSet.fromJson)
          .toList(),
      pagination: _paginationFrom(response, response.data),
    );
  }

  Future<WebDJSet> fetchSet(String id) async {
    final response = await _dio.get<dynamic>('/v1/dj-sets/$id');
    return WebDJSet.fromJson(LiveApiPayload.object(response.data));
  }

  Future<List<WebSetComment>> fetchComments(
    String setId, {
    int page = 1,
    int limit = 20,
  }) async {
    final result = await fetchCommentsPage(setId, page: page, limit: limit);
    return result.items;
  }

  Future<BFFListPage<WebSetComment>> fetchCommentsPage(
    String setId, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/dj-sets/$setId/comments',
      queryParameters: {'page': page, 'limit': limit},
    );
    return BFFListPage(
      items: LiveApiPayload.items(response.data)
          .whereType<Map<String, dynamic>>()
          .map(WebSetComment.fromJson)
          .toList(),
      pagination: _paginationFrom(response, response.data),
    );
  }

  Future<WebSetComment> addComment(
    String setId, {
    required String content,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/dj-sets/$setId/comments',
      data: {'content': content},
    );
    return WebSetComment.fromJson(LiveApiPayload.object(response.data));
  }

  Future<WebSetComment> updateComment(
    String commentId, {
    required String content,
  }) async {
    final response = await _dio.patch<dynamic>(
      '/v1/comments/$commentId',
      data: {'content': content},
    );
    return WebSetComment.fromJson(LiveApiPayload.object(response.data));
  }

  Future<void> deleteComment(String commentId) async {
    await _dio.delete<void>('/v1/comments/$commentId');
  }

  Future<WebDJSet> createSet(Map<String, dynamic> payload) async {
    final response = await _dio.post<dynamic>(
      '/v1/dj-sets',
      data: payload,
    );
    return WebDJSet.fromJson(LiveApiPayload.object(response.data));
  }

  Future<WebDJSet> updateSet(String id, Map<String, dynamic> payload) async {
    final response = await _dio.patch<dynamic>(
      '/v1/dj-sets/$id',
      data: payload,
    );
    return WebDJSet.fromJson(LiveApiPayload.object(response.data));
  }

  Future<void> deleteSet(String id) async {
    await _dio.delete<void>('/v1/dj-sets/$id');
  }

  Future<ShareLinkPayload> resolveShareLink({
    required WebDJSet djSet,
    String channel = 'system_share',
  }) async {
    final canonicalUrl = 'https://ravehub.top/set/${djSet.id}';
    final subtitle = [
      if (djSet.djName.trim().isNotEmpty) djSet.djName.trim(),
      if (djSet.eventName.trim().isNotEmpty) djSet.eventName.trim(),
      if (djSet.venue.trim().isNotEmpty) djSet.venue.trim(),
    ].join(' · ');

    final response = await _dio.post<dynamic>(
      '/v1/share-links/resolve',
      data: {
        'targetType': 'set',
        'targetId': djSet.id,
        'channel': channel,
        'preferPermanent': true,
        'targetSeed': {
          'title': djSet.title,
          if (subtitle.isNotEmpty) 'subtitle': subtitle,
          if (djSet.thumbnailUrl.isNotEmpty) 'imageUrl': djSet.thumbnailUrl,
          'canonicalUrl': canonicalUrl,
          'deepLink': 'raver://set/${djSet.id}',
          'fallbackUrl': canonicalUrl,
          'previewType': 'content_card',
          'visibility': 'public',
        },
      },
    );
    return ShareLinkPayload.fromJson(LiveApiPayload.object(response.data));
  }

  Future<WebDJSet> replaceTracks(
    String setId,
    List<Map<String, dynamic>> tracks,
  ) async {
    final response = await _dio.put<dynamic>(
      '/v1/dj-sets/$setId/tracks',
      data: {'tracks': tracks},
    );
    return WebDJSet.fromJson(LiveApiPayload.object(response.data));
  }

  Future<void> autoLinkTracks(String setId) async {
    await _dio.post<void>('/v1/dj-sets/$setId/auto-link');
  }

  Future<Map<String, String>> previewVideo(String videoUrl) async {
    final response = await _dio.get<dynamic>(
      '/v1/dj-sets/preview',
      queryParameters: {'videoUrl': videoUrl},
    );
    final object = LiveApiPayload.object(response.data);
    return object.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }

  Future<String> uploadSetAudio(String localPath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(localPath),
    });
    final response = await _dio.post<dynamic>(
      '/v1/dj-sets/upload-audio',
      data: formData,
    );
    final object = LiveApiPayload.object(response.data);
    final url = object['url'] ?? object['audioUrl'] ?? object['audioURL'];
    if (url is String && url.isNotEmpty) return url;
    throw StateError('Set audio upload response did not include a URL.');
  }

  Future<String> uploadSetThumbnail(String localPath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(localPath),
    });
    final response = await _dio.post<dynamic>(
      '/v1/dj-sets/upload-thumbnail',
      data: formData,
    );
    return _urlFromUploadPayload(
      response.data,
      fallbackError: 'Set thumbnail upload response did not include a URL.',
    );
  }

  Future<String> uploadSetVideo(String localPath) async {
    final formData = FormData.fromMap({
      'video': await MultipartFile.fromFile(localPath),
    });
    final response = await _dio.post<dynamic>(
      '/v1/dj-sets/upload-video',
      data: formData,
    );
    return _urlFromUploadPayload(
      response.data,
      fallbackError: 'Set video upload response did not include a URL.',
    );
  }
}

String _urlFromUploadPayload(dynamic payload, {required String fallbackError}) {
  final object = LiveApiPayload.object(payload);
  final url = object['url'] ??
      object['videoUrl'] ??
      object['videoURL'] ??
      object['thumbnailUrl'] ??
      object['thumbnailURL'];
  if (url is String && url.isNotEmpty) return url;
  throw StateError(fallbackError);
}

BFFPagination? _paginationFrom(Response<dynamic> response, Object? payload) {
  final extra = response.extra[kPaginationExtraKey];
  if (extra is Map<String, dynamic>) {
    return BFFPagination.fromJson(extra);
  }
  return LiveApiPayload.pagination(payload);
}
