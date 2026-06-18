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
    this.commentsPage = 0,
    this.commentsTotalPages = 1,
    this.isLoading = false,
    this.errorMessage,
    this.commentInput = '',
    this.isSendingComment = false,
    this.isLoadingMoreComments = false,
    this.isDeletingSet = false,
  });

  final WebDJSet? djSet;
  final List<WebSetComment> comments;
  final int commentsPage;
  final int commentsTotalPages;
  final bool isLoading;
  final String? errorMessage;
  final String commentInput;
  final bool isSendingComment;
  final bool isLoadingMoreComments;
  final bool isDeletingSet;

  bool get canLoadMoreComments =>
      commentsPage < commentsTotalPages && !isLoadingMoreComments;

  SetDetailState copyWith({
    WebDJSet? djSet,
    List<WebSetComment>? comments,
    int? commentsPage,
    int? commentsTotalPages,
    bool? isLoading,
    String? errorMessage,
    String? commentInput,
    bool? isSendingComment,
    bool? isLoadingMoreComments,
    bool? isDeletingSet,
    bool clearError = false,
  }) {
    return SetDetailState(
      djSet: djSet ?? this.djSet,
      comments: comments ?? this.comments,
      commentsPage: commentsPage ?? this.commentsPage,
      commentsTotalPages: commentsTotalPages ?? this.commentsTotalPages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      commentInput: commentInput ?? this.commentInput,
      isSendingComment: isSendingComment ?? this.isSendingComment,
      isLoadingMoreComments:
          isLoadingMoreComments ?? this.isLoadingMoreComments,
      isDeletingSet: isDeletingSet ?? this.isDeletingSet,
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
      final set = await _api.fetchSet(setId);
      final commentsPage = await _api.fetchCommentsPage(setId, page: 1);
      final pagination = commentsPage.pagination;
      state = state.copyWith(
        djSet: set,
        comments: commentsPage.items,
        commentsPage: pagination?.page ?? (commentsPage.items.isEmpty ? 0 : 1),
        commentsTotalPages: pagination?.totalPages ?? 1,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loadMoreComments() async {
    if (!state.canLoadMoreComments) return;
    state = state.copyWith(isLoadingMoreComments: true, clearError: true);
    try {
      final nextPage = state.commentsPage + 1;
      final result = await _api.fetchCommentsPage(setId, page: nextPage);
      final existingIds = state.comments.map((comment) => comment.id).toSet();
      final newComments = result.items
          .where((comment) => !existingIds.contains(comment.id))
          .toList();
      final pagination = result.pagination;
      state = state.copyWith(
        comments: [...state.comments, ...newComments],
        commentsPage: pagination?.page ?? nextPage,
        commentsTotalPages: pagination?.totalPages ?? state.commentsTotalPages,
        isLoadingMoreComments: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMoreComments: false,
        errorMessage: e.toString(),
      );
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
      state =
          state.copyWith(isSendingComment: false, errorMessage: e.toString());
    }
  }

  Future<void> updateComment(String commentId, String content) async {
    final text = content.trim();
    if (commentId.isEmpty || text.isEmpty) return;
    state = state.copyWith(clearError: true);
    try {
      final updated = await _api.updateComment(commentId, content: text);
      state = state.copyWith(
        comments: [
          for (final comment in state.comments)
            if (comment.id == commentId) updated else comment,
        ],
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteComment(String commentId) async {
    if (commentId.isEmpty) return;
    state = state.copyWith(clearError: true);
    try {
      await _api.deleteComment(commentId);
      state = state.copyWith(
        comments: [
          for (final comment in state.comments)
            if (comment.id != commentId) comment,
        ],
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<bool> deleteSet() async {
    if (state.isDeletingSet) return false;
    state = state.copyWith(isDeletingSet: true, clearError: true);
    try {
      await _api.deleteSet(setId);
      state = state.copyWith(isDeletingSet: false);
      return true;
    } catch (e) {
      state = state.copyWith(isDeletingSet: false, errorMessage: e.toString());
      return false;
    }
  }
}

final setDetailProvider = StateNotifierProvider.autoDispose
    .family<SetDetailNotifier, SetDetailState, String>((ref, setId) {
  return SetDetailNotifier(ref.watch(setApiProvider), setId);
});
