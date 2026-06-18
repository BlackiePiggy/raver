import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_network/raver_network.dart';

class DjApi {
  final Dio _dio;

  DjApi(this._dio);

  Future<BFFListPage<WebDJ>> fetchDJs({
    int page = 1,
    int limit = 25,
    String? search,
    String sortBy = 'random',
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/djs',
      queryParameters: {
        'page': page,
        'limit': limit,
        'sortBy': sortBy,
        if (search != null) 'search': search,
      },
    );
    return BFFListPage(
      items: LiveApiPayload.items(response.data)
          .whereType<Map<String, dynamic>>()
          .map(WebDJ.fromJson)
          .toList(),
      pagination: _paginationFrom(response, response.data),
    );
  }

  Future<List<WebDJ>> fetchSpotlightDJs({int limit = 10}) async {
    final response = await _dio.get<dynamic>(
      '/v1/djs/recommendations',
      queryParameters: {'limit': limit},
    );
    return LiveApiPayload.items(
      response.data,
    ).whereType<Map<String, dynamic>>().map(WebDJ.fromJson).toList();
  }

  Future<WebDJ> fetchDJ(String id) async {
    final response = await _dio.get<dynamic>('/v1/djs/$id');
    return WebDJ.fromJson(LiveApiPayload.object(response.data));
  }

  Future<WebDJ> toggleFollow(String djId, {required bool follow}) async {
    final response = await _dio.post<dynamic>(
      '/v1/djs/$djId/follow',
      data: {'follow': follow},
    );
    return WebDJ.fromJson(LiveApiPayload.object(response.data));
  }

  Future<BFFListPage<WebDJSet>> fetchDJSets(
    String djId, {
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _dio.get<dynamic>(
      '/v1/djs/$djId/sets',
      queryParameters: {'page': page, 'limit': limit},
    );
    return BFFListPage(
      items: LiveApiPayload.items(response.data)
          .whereType<Map<String, dynamic>>()
          .map(WebDJSet.fromJson)
          .toList(),
      pagination: _paginationFrom(response, response.data),
    );
  }

  Future<WebDJ> createDJ(Map<String, dynamic> payload) async {
    final response = await _dio.post<dynamic>(
      '/v1/djs',
      data: payload,
    );
    return WebDJ.fromJson(LiveApiPayload.object(response.data));
  }

  Future<WebDJ> updateDJ(String id, Map<String, dynamic> payload) async {
    final response = await _dio.put<dynamic>(
      '/v1/djs/$id',
      data: payload,
    );
    return WebDJ.fromJson(LiveApiPayload.object(response.data));
  }

  Future<String> uploadDjAvatar(
    String localPath, {
    String? djId,
    String? draftId,
    String usage = 'avatar',
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(localPath),
      'usage': usage,
      if (djId != null && djId.isNotEmpty) 'djId': djId,
      if (draftId != null && draftId.isNotEmpty) 'draftId': draftId,
    });
    final response = await _dio.post<dynamic>(
      '/v1/djs/upload-image',
      data: formData,
    );
    return _urlFromUploadPayload(
      response.data,
      fallbackError: 'DJ image upload response did not include a URL.',
    );
  }

  Future<WebDJ> importFromSpotify({required String spotifyArtistId}) async {
    final response = await _dio.post<dynamic>(
      '/v1/djs/import/spotify',
      data: {'spotifyArtistId': spotifyArtistId},
    );
    return WebDJ.fromJson(LiveApiPayload.object(response.data));
  }

  Future<WebDJ> importFromDiscogs({required String discogsArtistId}) async {
    final response = await _dio.post<dynamic>(
      '/v1/djs/import/discogs',
      data: {'discogsArtistId': discogsArtistId},
    );
    return WebDJ.fromJson(LiveApiPayload.object(response.data));
  }
}

String _urlFromUploadPayload(dynamic payload, {required String fallbackError}) {
  final object = LiveApiPayload.object(payload);
  final url = object['url'] ??
      object['imageUrl'] ??
      object['imageURL'] ??
      object['avatarUrl'] ??
      object['avatarURL'];
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
