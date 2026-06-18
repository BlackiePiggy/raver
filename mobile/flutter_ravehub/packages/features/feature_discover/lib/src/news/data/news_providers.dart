import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

import '../../_shared/discover_dio.dart';
import 'news_api.dart';

final newsApiProvider = Provider<NewsApi>((ref) {
  return NewsApi(ref.watch(dioProvider));
});

final dioProvider = Provider<Dio>((ref) {
  return ref.watch(discoverDioProvider);
});

enum NewsCategory {
  all('all'),
  festival('festival'),
  scene('scene'),
  gear('gear'),
  industry('industry'),
  community('community');

  const NewsCategory(this.value);
  final String value;

  String get title {
    switch (this) {
      case NewsCategory.all:
        return 'All';
      case NewsCategory.festival:
        return 'Festival';
      case NewsCategory.scene:
        return 'Live Scene';
      case NewsCategory.gear:
        return 'Gear';
      case NewsCategory.industry:
        return 'Industry';
      case NewsCategory.community:
        return 'Community';
    }
  }
}

class NewsListState {
  const NewsListState({
    this.articles = const [],
    this.nextCursor,
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.hasLoaded = false,
    this.selectedCategory = NewsCategory.all,
  });

  final List<NewsArticle> articles;
  final String? nextCursor;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final bool hasLoaded;
  final NewsCategory selectedCategory;

  List<NewsArticle> get displayedArticles {
    if (selectedCategory == NewsCategory.all) return articles;
    return articles.where((a) => a.category == selectedCategory.value).toList();
  }

  bool get canLoadMore => nextCursor != null && !isLoading;

  NewsListState copyWith({
    List<NewsArticle>? articles,
    String? nextCursor,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    bool? hasLoaded,
    NewsCategory? selectedCategory,
    bool clearError = false,
    bool clearCursor = false,
  }) {
    return NewsListState(
      articles: articles ?? this.articles,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasLoaded: hasLoaded ?? this.hasLoaded,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }
}

class NewsListNotifier extends StateNotifier<NewsListState> {
  final NewsApi _api;

  NewsListNotifier(this._api) : super(const NewsListState());

  void setCategory(NewsCategory category) {
    state = state.copyWith(selectedCategory: category);
  }

  Future<void> loadIfNeeded() async {
    if (state.hasLoaded) return;
    await reload();
  }

  Future<void> reload() async {
    if (state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      isRefreshing: state.hasLoaded,
      clearError: true,
    );
    try {
      final page = await _api.fetchNewsPage();
      final deduped = _deduplicateAndSort(page.articles);
      state = state.copyWith(
        articles: deduped,
        nextCursor: page.nextCursor,
        isLoading: false,
        isRefreshing: false,
        hasLoaded: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: e.toString(),
        hasLoaded: true,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    state = state.copyWith(isLoading: true);
    try {
      final page = await _api.fetchNewsPage(cursor: state.nextCursor);
      final existingIds = state.articles.map((a) => a.id).toSet();
      final newArticles =
          page.articles.where((a) => !existingIds.contains(a.id)).toList();
      final merged = [...state.articles, ...newArticles];
      state = state.copyWith(
        articles: _deduplicateAndSort(merged),
        nextCursor: page.nextCursor,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  List<NewsArticle> _deduplicateAndSort(List<NewsArticle> items) {
    final seen = <String>{};
    final deduped = items.where((a) => seen.add(a.id)).toList();
    deduped.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return deduped;
  }
}

final newsListProvider =
    StateNotifierProvider.autoDispose<NewsListNotifier, NewsListState>((ref) {
  return NewsListNotifier(ref.watch(newsApiProvider));
});

class NewsDetailState {
  const NewsDetailState({
    this.article,
    this.relatedDjs = const [],
    this.relatedEvents = const [],
    this.comments = const [],
    this.visibleCommentCount = 20,
    this.isLoadingBindings = false,
    this.isLoadingComments = false,
    this.isSendingComment = false,
    this.isLoading = false,
    this.errorMessage,
    this.commentErrorMessage,
  });

  final NewsArticle? article;
  final List<WebDJ> relatedDjs;
  final List<WebEvent> relatedEvents;
  final List<Comment> comments;
  final int visibleCommentCount;
  final bool isLoadingBindings;
  final bool isLoadingComments;
  final bool isSendingComment;
  final bool isLoading;
  final String? errorMessage;
  final String? commentErrorMessage;

  List<Comment> get visibleComments =>
      comments.take(visibleCommentCount).toList();

  bool get canRevealMoreComments => visibleCommentCount < comments.length;

  List<String> get unresolvedBoundDjIds {
    final resolved = relatedDjs.map((dj) => dj.id).toSet();
    return article?.boundDjIds.where((id) => !resolved.contains(id)).toList() ??
        const [];
  }

  List<String> get unresolvedBoundEventIds {
    final resolved = relatedEvents.map((event) => event.id).toSet();
    return article?.boundEventIds
            .where((id) => !resolved.contains(id))
            .toList() ??
        const [];
  }

  bool get hasBoundEntities {
    final article = this.article;
    if (article == null) return false;
    return article.boundDjIds.isNotEmpty || article.boundEventIds.isNotEmpty;
  }

  NewsDetailState copyWith({
    NewsArticle? article,
    List<WebDJ>? relatedDjs,
    List<WebEvent>? relatedEvents,
    List<Comment>? comments,
    int? visibleCommentCount,
    bool? isLoadingBindings,
    bool? isLoadingComments,
    bool? isSendingComment,
    bool? isLoading,
    String? errorMessage,
    String? commentErrorMessage,
    bool clearError = false,
    bool clearCommentError = false,
  }) {
    return NewsDetailState(
      article: article ?? this.article,
      relatedDjs: relatedDjs ?? this.relatedDjs,
      relatedEvents: relatedEvents ?? this.relatedEvents,
      comments: comments ?? this.comments,
      visibleCommentCount: visibleCommentCount ?? this.visibleCommentCount,
      isLoadingBindings: isLoadingBindings ?? this.isLoadingBindings,
      isLoadingComments: isLoadingComments ?? this.isLoadingComments,
      isSendingComment: isSendingComment ?? this.isSendingComment,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      commentErrorMessage: clearCommentError
          ? null
          : (commentErrorMessage ?? this.commentErrorMessage),
    );
  }
}

class NewsDetailNotifier extends StateNotifier<NewsDetailState> {
  final NewsApi _api;
  final String articleId;

  NewsDetailNotifier(this._api, this.articleId)
      : super(const NewsDetailState());

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final article = await _api.fetchArticle(articleId);
      state = state.copyWith(article: article, isLoading: false);
      await _loadBoundEntities(article);
      await loadComments(reset: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> _loadBoundEntities(NewsArticle article) async {
    if (article.boundDjIds.isEmpty && article.boundEventIds.isEmpty) return;
    state = state.copyWith(isLoadingBindings: true);
    try {
      final results = await Future.wait([
        _api.fetchBoundDJs(article.boundDjIds),
        _api.fetchBoundEvents(article.boundEventIds),
      ]);
      state = state.copyWith(
        relatedDjs: results[0] as List<WebDJ>,
        relatedEvents: results[1] as List<WebEvent>,
        isLoadingBindings: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingBindings: false);
    }
  }

  Future<void> loadComments({bool reset = false}) async {
    if (state.isLoadingComments) return;
    if (reset) {
      state = state.copyWith(
        comments: const [],
        visibleCommentCount: 20,
        clearCommentError: true,
      );
    }
    state = state.copyWith(isLoadingComments: true, clearCommentError: true);
    try {
      final comments = await _api.fetchComments(articleId);
      state = state.copyWith(
        comments: comments,
        visibleCommentCount: comments.length < 20 ? comments.length : 20,
        isLoadingComments: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingComments: false,
        commentErrorMessage: e.toString(),
      );
    }
  }

  Future<bool> submitComment(String content) async {
    final text = content.trim();
    if (text.isEmpty || state.isSendingComment) return false;
    state = state.copyWith(isSendingComment: true, clearCommentError: true);
    try {
      final comment = await _api.addComment(articleId, content: text);
      final comments = [...state.comments, comment];
      final article = state.article;
      state = state.copyWith(
        article: article == null
            ? null
            : article.copyWith(replyCount: article.replyCount + 1),
        comments: comments,
        visibleCommentCount: comments.length,
        isSendingComment: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSendingComment: false,
        commentErrorMessage: e.toString(),
      );
      return false;
    }
  }

  void revealMoreComments() {
    if (!state.canRevealMoreComments) return;
    state = state.copyWith(
      visibleCommentCount: (state.visibleCommentCount + 20).clamp(
        0,
        state.comments.length,
      ),
    );
  }
}

final newsDetailProvider = StateNotifierProvider.autoDispose
    .family<NewsDetailNotifier, NewsDetailState, String>((ref, articleId) {
  return NewsDetailNotifier(ref.watch(newsApiProvider), articleId);
});
