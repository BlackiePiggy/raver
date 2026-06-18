class NewsArticle {
  final String id;
  final String title;
  final String summary;
  final String body;
  final String category;
  final String source;
  final String? coverImageUrl;
  final String? link;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final List<String> boundDjIds;
  final List<String> boundEventIds;
  final List<String> boundBrandIds;
  final int replyCount;
  final String createdAt;

  /// Compatibility alias for editor screens that expect tag chips.
  List<String> get tags => const [];

  const NewsArticle({
    required this.id,
    required this.title,
    this.summary = '',
    this.body = '',
    this.category = '',
    this.source = '',
    this.coverImageUrl,
    this.link,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    this.boundDjIds = const [],
    this.boundEventIds = const [],
    this.boundBrandIds = const [],
    this.replyCount = 0,
    required this.createdAt,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
    id: json['id'] as String,
    title: json['title'] as String,
    summary: json['summary'] as String? ?? '',
    body: json['body'] as String? ?? '',
    category: json['category'] as String? ?? '',
    source: json['source'] as String? ?? '',
    coverImageUrl:
        json['coverImageUrl'] as String? ?? json['coverImageURL'] as String?,
    link: json['link'] as String?,
    authorId: json['authorId'] as String? ?? json['authorID'] as String? ?? '',
    authorName:
        json['authorName'] as String? ??
        json['authorUsername'] as String? ??
        '',
    authorAvatarUrl:
        json['authorAvatarUrl'] as String? ??
        json['authorAvatarURL'] as String?,
    boundDjIds:
        (json['boundDjIds'] as List<dynamic>? ??
                json['boundDjIDs'] as List<dynamic>? ??
                [])
            .map((e) => e as String)
            .toList(),
    boundEventIds:
        (json['boundEventIds'] as List<dynamic>? ??
                json['boundEventIDs'] as List<dynamic>? ??
                [])
            .map((e) => e as String)
            .toList(),
    boundBrandIds:
        (json['boundBrandIds'] as List<dynamic>? ??
                json['boundBrandIDs'] as List<dynamic>? ??
                [])
            .map((e) => e as String)
            .toList(),
    replyCount: json['replyCount'] as int? ?? 0,
    createdAt:
        json['createdAt'] as String? ?? json['publishedAt'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'body': body,
    'category': category,
    'source': source,
    if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
    if (link != null) 'link': link,
    'authorId': authorId,
    'authorName': authorName,
    if (authorAvatarUrl != null) 'authorAvatarUrl': authorAvatarUrl,
    'boundDjIds': boundDjIds,
    'boundEventIds': boundEventIds,
    'boundBrandIds': boundBrandIds,
    'replyCount': replyCount,
    'createdAt': createdAt,
  };

  NewsArticle copyWith({
    String? id,
    String? title,
    String? summary,
    String? body,
    String? category,
    String? source,
    String? coverImageUrl,
    String? link,
    String? authorId,
    String? authorName,
    String? authorAvatarUrl,
    List<String>? boundDjIds,
    List<String>? boundEventIds,
    List<String>? boundBrandIds,
    int? replyCount,
    String? createdAt,
  }) => NewsArticle(
    id: id ?? this.id,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    body: body ?? this.body,
    category: category ?? this.category,
    source: source ?? this.source,
    coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    link: link ?? this.link,
    authorId: authorId ?? this.authorId,
    authorName: authorName ?? this.authorName,
    authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    boundDjIds: boundDjIds ?? this.boundDjIds,
    boundEventIds: boundEventIds ?? this.boundEventIds,
    boundBrandIds: boundBrandIds ?? this.boundBrandIds,
    replyCount: replyCount ?? this.replyCount,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NewsArticle &&
        other.id == id &&
        other.title == title &&
        other.authorId == authorId;
  }

  @override
  int get hashCode => Object.hash(id, title, authorId);

  @override
  String toString() =>
      'NewsArticle(id: $id, title: $title, authorName: $authorName)';
}

class NewsPage {
  final List<NewsArticle> articles;
  final String? nextCursor;

  const NewsPage({required this.articles, this.nextCursor});

  factory NewsPage.fromJson(Map<String, dynamic> json) => NewsPage(
    articles: (json['articles'] as List<dynamic>? ?? [])
        .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
        .toList(),
    nextCursor: json['nextCursor'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'articles': articles.map((e) => e.toJson()).toList(),
    if (nextCursor != null) 'nextCursor': nextCursor,
  };

  NewsPage copyWith({List<NewsArticle>? articles, String? nextCursor}) =>
      NewsPage(
        articles: articles ?? this.articles,
        nextCursor: nextCursor ?? this.nextCursor,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NewsPage && other.nextCursor == nextCursor;
  }

  @override
  int get hashCode => nextCursor.hashCode;

  @override
  String toString() =>
      'NewsPage(articles: ${articles.length} items, nextCursor: $nextCursor)';
}
