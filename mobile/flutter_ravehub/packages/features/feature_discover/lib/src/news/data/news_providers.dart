import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

import 'news_api.dart';

final newsApiProvider = Provider<NewsApi>((ref) {
  return NewsApi(ref.watch(dioProvider));
});

final dioProvider = Provider<Dio>((ref) {
  throw UnimplementedError('dioProvider must be overridden at app level');
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
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
    this.isLoading = false,
    this.errorMessage,
  });

  final NewsArticle? article;
  final bool isLoading;
  final String? errorMessage;

  NewsDetailState copyWith({
    NewsArticle? article,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NewsDetailState(
      article: article ?? this.article,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final newsDetailProvider = StateNotifierProvider.autoDispose
    .family<NewsDetailNotifier, NewsDetailState, String>((ref, articleId) {
  return NewsDetailNotifier(ref.watch(newsApiProvider), articleId);
});
