import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class DjApi {
  final Dio _dio;

  DjApi(this._dio);

  Future<BFFListPage<WebDJ>> fetchDJs({
    int page = 1,
    int limit = 25,
    String? search,
    String sortBy = 'random',
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/djs',
      queryParameters: {
        'page': page,
        'limit': limit,
        'sortBy': sortBy,
        if (search != null) 'search': search,
      },
    );
    final data = response.data!;
    final items = (data['items'] as List? ?? data['data'] as List? ?? [])
        .map((e) => WebDJ.fromJson(e as Map<String, dynamic>))
        .toList();
    final pagination = data['pagination'] != null
        ? BFFPagination.fromJson(data['pagination'] as Map<String, dynamic>)
        : null;
    return BFFListPage(items: items, pagination: pagination);
  }

  Future<List<WebDJ>> fetchSpotlightDJs({int limit = 10}) async {
    final response = await _dio.get<List<dynamic>>(
      '/v1/djs/spotlight',
      queryParameters: {'limit': limit},
    );
    return (response.data ?? [])
        .map((e) => WebDJ.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WebDJ> fetchDJ(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/djs/$id');
    return WebDJ.fromJson(response.data!);
  }

  Future<WebDJ> toggleFollow(String djId, {required bool follow}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/djs/$djId/follow',
      data: {'follow': follow},
    );
    return WebDJ.fromJson(response.data!);
  }

  Future<BFFListPage<WebDJSet>> fetchDJSets(
    String djId, {
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/djs/$djId/sets',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data!;
    final items = (data['items'] as List? ?? data['data'] as List? ?? [])
        .map((e) => WebDJSet.fromJson(e as Map<String, dynamic>))
        .toList();
    final pagination = data['pagination'] != null
        ? BFFPagination.fromJson(data['pagination'] as Map<String, dynamic>)
        : null;
    return BFFListPage(items: items, pagination: pagination);
  }

  Future<WebDJ> createDJ(Map<String, dynamic> payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/djs',
      data: payload,
    );
    return WebDJ.fromJson(response.data!);
  }

  Future<WebDJ> updateDJ(String id, Map<String, dynamic> payload) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/v1/djs/$id',
      data: payload,
    );
    return WebDJ.fromJson(response.data!);
  }

  Future<String> uploadDjAvatar(String localPath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(localPath),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/upload/djs/avatar',
      data: formData,
    );
    return response.data!['url'] as String;
  }

  Future<WebDJ> importFromSpotify({required String spotifyArtistId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/djs/import/spotify',
      data: {'spotifyArtistId': spotifyArtistId},
    );
    return WebDJ.fromJson(response.data!);
  }

  Future<WebDJ> importFromDiscogs({required String discogsArtistId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/djs/import/discogs',
      data: {'discogsArtistId': discogsArtistId},
    );
    return WebDJ.fromJson(response.data!);
  }
}
