import 'package:dio/dio.dart';
import 'package:raver_models/raver_models.dart';

class NewsApi {
  final Dio _dio;

  NewsApi(this._dio);

  Future<NewsPage> fetchNewsPage({String? cursor}) async {
    final response = await _dio.get<dynamic>(
      '/v1/news',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': 20,
      },
    );
    final articles = LiveApiPayload.items(
      response.data,
      itemKeys: const ['articles', 'items', 'list', 'data'],
    ).whereType<Map<String, dynamic>>().map(NewsArticle.fromJson).toList();
    return NewsPage(
      articles: articles,
      nextCursor: LiveApiPayload.cursor(response.data),
    );
  }

  Future<NewsArticle> fetchArticle(String id) async {
    final response = await _dio.get<dynamic>('/v1/news/$id');
    return NewsArticle.fromJson(LiveApiPayload.object(response.data));
  }

  Future<List<WebDJ>> fetchBoundDJs(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final results = await Future.wait(ids.map(_fetchDjOrNull));
    final byId = <String, WebDJ>{
      for (final dj in results)
        if (dj != null) dj.id: dj,
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!
    ];
  }

  Future<List<WebEvent>> fetchBoundEvents(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final results = await Future.wait(ids.map(_fetchEventOrNull));
    final byId = <String, WebEvent>{
      for (final event in results)
        if (event != null) event.id: event,
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!
    ];
  }

  Future<WebDJ?> _fetchDjOrNull(String id) async {
    try {
      final response = await _dio.get<dynamic>('/v1/djs/$id');
      return WebDJ.fromJson(LiveApiPayload.object(response.data));
    } catch (_) {
      return null;
    }
  }

  Future<WebEvent?> _fetchEventOrNull(String id) async {
    try {
      final response = await _dio.get<dynamic>('/v1/events/$id');
      return WebEvent.fromJson(LiveApiPayload.object(response.data));
    } catch (_) {
      return null;
    }
  }

  Future<List<WebDJ>> searchDJs(String query, {int limit = 20}) async {
    final response = await _dio.get<dynamic>(
      '/v1/djs',
      queryParameters: {
        'page': 1,
        'limit': limit,
        'sortBy': query.trim().isEmpty ? 'random' : 'relevance',
        if (query.trim().isNotEmpty) 'search': query.trim(),
      },
    );
    return LiveApiPayload.items(
      response.data,
    ).whereType<Map<String, dynamic>>().map(WebDJ.fromJson).toList();
  }

  Future<List<WebEvent>> searchEvents(String query, {int limit = 20}) async {
    final response = await _dio.get<dynamic>(
      '/v1/events',
      queryParameters: {
        'page': 1,
        'limit': limit,
        if (query.trim().isNotEmpty) 'search': query.trim(),
      },
    );
    return LiveApiPayload.items(
      response.data,
    ).whereType<Map<String, dynamic>>().map(WebEvent.fromJson).toList();
  }

  Future<ShareLinkPayload> resolveShareLink({
    required NewsArticle article,
    String channel = 'system_share',
  }) async {
    final canonicalUrl = 'https://ravehub.top/n/${article.id}';
    final response = await _dio.post<dynamic>(
      '/v1/share-links/resolve',
      data: {
        'targetType': 'news',
        'targetId': article.id,
        'channel': channel,
        'preferPermanent': true,
        'targetSeed': {
          'title': article.title,
          if (article.summary.isNotEmpty) 'subtitle': article.summary,
          if (article.coverImageUrl != null &&
              article.coverImageUrl!.isNotEmpty)
            'imageUrl': article.coverImageUrl,
          'canonicalUrl': canonicalUrl,
          'deepLink': 'raver://news/${article.id}',
          'fallbackUrl': canonicalUrl,
          'previewType': 'content_card',
          'visibility': 'public',
        },
      },
    );
    return ShareLinkPayload.fromJson(LiveApiPayload.object(response.data));
  }

  Future<List<Comment>> fetchComments(String articleId) async {
    final response = await _dio.get<dynamic>('/v1/news/$articleId/comments');
    return LiveApiPayload.items(
      response.data,
      itemKeys: const ['comments', 'items', 'list', 'data'],
    ).whereType<Map<String, dynamic>>().map(Comment.fromJson).toList();
  }

  Future<Comment> addComment(
    String articleId, {
    required String content,
    String? parentCommentId,
  }) async {
    final response = await _dio.post<dynamic>(
      '/v1/news/$articleId/comments',
      data: {
        'content': content,
        if (parentCommentId != null && parentCommentId.trim().isNotEmpty)
          'parentCommentID': parentCommentId.trim(),
      },
    );
    return Comment.fromJson(LiveApiPayload.object(response.data));
  }

  /// Creates a new news article.
  Future<NewsArticleSaveResult> createArticle(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<dynamic>(
      '/v1/news',
      data: payload,
    );
    return _saveResultFromPayload(response.data);
  }

  /// Updates an existing news article.
  Future<NewsArticleSaveResult> updateArticle(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch<dynamic>(
      '/v1/news/$id',
      data: payload,
    );
    return _saveResultFromPayload(response.data);
  }

  /// Uploads a cover image and returns the remote URL.
  Future<String> uploadCoverImage(String localPath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(localPath),
      'usage': 'news_cover',
    });
    final response = await _dio.post<dynamic>(
      '/v1/events/upload-image',
      data: formData,
    );
    return _urlFromUploadPayload(
      response.data,
      fallbackError: 'News cover upload response did not include a URL.',
    );
  }
}

class NewsArticleSaveResult {
  const NewsArticleSaveResult._({
    this.article,
    this.submission,
    this.message = '',
    this.status = '',
  });

  factory NewsArticleSaveResult.created(NewsArticle article) =>
      NewsArticleSaveResult._(article: article);

  factory NewsArticleSaveResult.submittedForReview({
    required ContentSubmissionSummary submission,
    String message = '',
    String status = '',
  }) =>
      NewsArticleSaveResult._(
        submission: submission,
        message: message,
        status: status,
      );

  final NewsArticle? article;
  final ContentSubmissionSummary? submission;
  final String message;
  final String status;

  bool get isSubmittedForReview => submission != null;
}

String _urlFromUploadPayload(dynamic payload, {required String fallbackError}) {
  final object = LiveApiPayload.object(payload);
  final url = object['url'] ??
      object['imageUrl'] ??
      object['imageURL'] ??
      object['coverImageUrl'] ??
      object['coverImageURL'];
  if (url is String && url.isNotEmpty) return url;
  throw StateError(fallbackError);
}

NewsArticleSaveResult _saveResultFromPayload(dynamic payload) {
  final object = LiveApiPayload.object(payload);
  final submission = object['submission'];
  final status = object['status']?.toString() ?? '';
  final looksSubmittedForReview = submission is Map<String, dynamic> ||
      {
        'submitted_for_review',
        'submitted-for-review',
        'reviewing',
        'pending',
      }.contains(status.trim().toLowerCase().replaceAll('_', '-'));

  if (looksSubmittedForReview) {
    final rawSubmission =
        submission is Map<String, dynamic> ? submission : object;
    return NewsArticleSaveResult.submittedForReview(
      submission: _contentSubmissionSummaryFromJson(
        rawSubmission,
        parentStatus: status,
      ),
      message: object['message']?.toString() ?? '',
      status: status,
    );
  }

  return NewsArticleSaveResult.created(NewsArticle.fromJson(object));
}

ContentSubmissionSummary _contentSubmissionSummaryFromJson(
  Map<String, dynamic> json, {
  String parentStatus = '',
}) {
  final now = DateTime.now().toIso8601String();
  final normalized = <String, dynamic>{
    'id': _stringFromAny(
      json['id'] ?? json['submissionId'] ?? json['submissionID'],
    ),
    'entityType': _stringFromAny(json['entityType'], fallback: 'news'),
    'entityName': _stringFromAny(
      json['entityName'] ?? json['title'] ?? json['name'],
      fallback: 'News',
    ),
    'status': _stringFromAny(
      json['status'],
      fallback: parentStatus.trim().isEmpty
          ? 'submitted_for_review'
          : parentStatus.trim(),
    ),
    'createdAt': _stringFromAny(json['createdAt'], fallback: now),
    'updatedAt': _stringFromAny(json['updatedAt'], fallback: now),
    if (json['statusLabel'] != null) 'statusLabel': json['statusLabel'],
    if (json['reviewStatusLabel'] != null)
      'reviewStatusLabel': json['reviewStatusLabel'],
    if (json['metadata'] != null) 'metadata': json['metadata'],
    if (json['reviewNotes'] != null) 'reviewNotes': json['reviewNotes'],
    if (json['reviewNote'] != null) 'reviewNote': json['reviewNote'],
  };
  return ContentSubmissionSummary.fromJson(normalized);
}

String _stringFromAny(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
