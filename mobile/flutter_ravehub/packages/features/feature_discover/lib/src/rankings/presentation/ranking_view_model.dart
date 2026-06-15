import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

import '../data/ranking_api.dart';

class RankingsState {
  const RankingsState({
    this.boards = const [],
    this.isLoading = false,
    this.error,
  });

  final List<RankingBoard> boards;
  final bool isLoading;
  final String? error;

  RankingsState copyWith({
    List<RankingBoard>? boards,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return RankingsState(
      boards: boards ?? this.boards,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RankingsNotifier extends StateNotifier<RankingsState> {
  RankingsNotifier(this._api) : super(const RankingsState()) {
    loadRankings();
  }

  final RankingApi _api;

  Future<void> loadRankings() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final boards = await _api.fetchRankings();
      state = state.copyWith(boards: boards, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

final rankingsProvider =
    StateNotifierProvider.autoDispose<RankingsNotifier, RankingsState>(
  (ref) {
    final api = ref.watch(rankingApiProvider);
    return RankingsNotifier(api);
  },
);

class RankingDetailState {
  const RankingDetailState({
    this.detail,
    this.isLoading = false,
    this.error,
    this.selectedYear,
  });

  final RankingBoardDetail? detail;
  final bool isLoading;
  final String? error;
  final int? selectedYear;
}

class RankingDetailNotifier extends StateNotifier<RankingDetailState> {
  RankingDetailNotifier(this._api, this._boardId)
      : super(const RankingDetailState()) {
    _load();
  }

  final RankingApi _api;
  final String _boardId;

  Future<void> _load({int? year}) async {
    state = RankingDetailState(isLoading: true, selectedYear: year);
    try {
      final detail = await _api.fetchRankingDetail(_boardId, year: year);
      state = RankingDetailState(detail: detail, selectedYear: year);
    } catch (e) {
      state = RankingDetailState(error: e.toString(), selectedYear: year);
    }
  }

  void selectYear(int year) => _load(year: year);
  Future<void> retry() => _load(year: state.selectedYear);
}

final rankingDetailProvider = StateNotifierProvider.autoDispose
    .family<RankingDetailNotifier, RankingDetailState, String>(
  (ref, boardId) {
    final api = ref.watch(rankingApiProvider);
    return RankingDetailNotifier(api, boardId);
  },
);
