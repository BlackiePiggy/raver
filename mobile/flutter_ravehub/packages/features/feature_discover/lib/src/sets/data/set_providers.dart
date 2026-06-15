import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

import '../../news/data/news_providers.dart';
import 'set_api.dart';

final setApiProvider = Provider<SetApi>((ref) {
  return SetApi(ref.watch(dioProvider));
});

enum SetSortBy {
  latest('latest'),
  popular('popular'),
  tracks('tracks');

  const SetSortBy(this.value);
  final String value;

  String get title {
    switch (this) {
      case SetSortBy.latest:
        return 'Latest';
      case SetSortBy.popular:
        return 'Popular';
      case SetSortBy.tracks:
        return 'Tracks';
    }
  }
}

class SetsListState {
  const SetsListState({
    this.sets = const [],
    this.page = 1,
    this.totalPages = 1,
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.hasLoaded = false,
    this.sortBy = SetSortBy.latest,
  });

  final List<WebDJSet> sets;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final bool hasLoaded;
  final SetSortBy sortBy;

  bool get canLoadMore => page < totalPages && !isLoading;

  SetsListState copyWith({
    List<WebDJSet>? sets,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    bool? hasLoaded,
    SetSortBy? sortBy,
    bool clearError = false,
  }) {
    return SetsListState(
      sets: sets ?? this.sets,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasLoaded: hasLoaded ?? this.hasLoaded,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class SetsListNotifier extends StateNotifier<SetsListState> {
  final SetApi _api;

  SetsListNotifier(this._api) : super(const SetsListState());

  Future<void> loadIfNeeded() async {
    if (state.hasLoaded) return;
    await reload();
  }

  void setSortBy(SetSortBy sortBy) {
    if (state.sortBy == sortBy) return;
    state = state.copyWith(sortBy: sortBy, sets: [], page: 1, hasLoaded: false);
    reload();
  }

  Future<void> reload() async {
    if (state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      isRefreshing: state.hasLoaded,
      clearError: true,
    );
    try {
      final result =
          await _api.fetchSets(page: 1, limit: 20, sortBy: state.sortBy.value);
      state = state.copyWith(
        sets: result.items,
        page: 1,
        totalPages: result.pagination?.totalPages ?? 1,
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
      final nextPage = state.page + 1;
      final result = await _api.fetchSets(
          page: nextPage, limit: 20, sortBy: state.sortBy.value);
      final existingIds = state.sets.map((s) => s.id).toSet();
      final newSets =
          result.items.where((s) => !existingIds.contains(s.id)).toList();
      state = state.copyWith(
        sets: [...state.sets, ...newSets],
        page: nextPage,
        totalPages: result.pagination?.totalPages ?? state.totalPages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final setsListProvider =
    StateNotifierProvider.autoDispose<SetsListNotifier, SetsListState>((ref) {
  return SetsListNotifier(ref.watch(setApiProvider));
});

class SetDetailState {
  const SetDetailState({
    this.djSet,
    this.comments = const [],
    this.isLoading = false,
    this.errorMessage,
    this.commentInput = '',
    this.isSendingComment = false,
  });

  final WebDJSet? djSet;
  final List<WebSetComment> comments;
  final bool isLoading;
  final String? errorMessage;
  final String commentInput;
  final bool isSendingComment;

  SetDetailState copyWith({
    WebDJSet? djSet,
    List<WebSetComment>? comments,
    bool? isLoading,
    String? errorMessage,
    String? commentInput,
    bool? isSendingComment,
    bool clearError = false,
  }) {
    return SetDetailState(
      djSet: djSet ?? this.djSet,
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      commentInput: commentInput ?? this.commentInput,
      isSendingComment: isSendingComment ?? this.isSendingComment,
    );
  }
}

class SetDetailNotifier extends StateNotifier<SetDetailState> {
  final SetApi _api;
  final String setId;

  SetDetailNotifier(this._api, this.setId) : super(const SetDetailState());

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _api.fetchSet(setId),
        _api.fetchComments(setId, page: 1, limit: 20),
      ]);
      state = state.copyWith(
        djSet: results[0] as WebDJSet,
        comments: results[1] as List<WebSetComment>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setCommentInput(String text) {
    state = state.copyWith(commentInput: text);
  }

  Future<void> submitComment() async {
    final text = state.commentInput.trim();
    if (text.isEmpty || state.isSendingComment) return;
    state = state.copyWith(isSendingComment: true);
    try {
      final comment = await _api.addComment(setId, content: text);
      state = state.copyWith(
        comments: [...state.comments, comment],
        commentInput: '',
        isSendingComment: false,
      );
    } catch (e) {
      state = state.copyWith(isSendingComment: false, errorMessage: e.toString());
    }
  }
}

final setDetailProvider = StateNotifierProvider.autoDispose
    .family<SetDetailNotifier, SetDetailState, String>((ref, setId) {
  return SetDetailNotifier(ref.watch(setApiProvider), setId);
});
