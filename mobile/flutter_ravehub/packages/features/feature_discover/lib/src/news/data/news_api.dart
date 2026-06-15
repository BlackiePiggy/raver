import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class NewsApi {
  final Dio _dio;

  NewsApi(this._dio);

  Future<NewsPage> fetchNewsPage({String? cursor}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/v1/news',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': 20,
      },
    );
    final data = response.data!;
    final articles = (data['items'] as List? ?? [])
        .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
        .toList();
    return NewsPage(
      articles: articles,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  Future<NewsArticle> fetchArticle(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/news/$id');
    return NewsArticle.fromJson(response.data!);
  }

  /// Creates a new news article.
  Future<NewsArticle> createArticle(Map<String, dynamic> payload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/news',
      data: payload,
    );
    return NewsArticle.fromJson(response.data!);
  }

  /// Updates an existing news article.
  Future<NewsArticle> updateArticle(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/v1/news/$id',
      data: payload,
    );
    return NewsArticle.fromJson(response.data!);
  }

  /// Uploads a cover image and returns the remote URL.
  Future<String> uploadCoverImage(String localPath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(localPath),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/upload/news/cover',
      data: formData,
    );
    return response.data!['url'] as String;
  }
}
