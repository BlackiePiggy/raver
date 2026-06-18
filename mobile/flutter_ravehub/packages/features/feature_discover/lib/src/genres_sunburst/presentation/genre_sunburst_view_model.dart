import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

import '../data/genre_api.dart';

class GenreSunburstState {
  const GenreSunburstState({
    this.roots = const [],
    this.isLoading = false,
    this.error,
    this.selectedGenreId,
  });

  final List<GenreSunburstNode> roots;
  final bool isLoading;
  final String? error;
  final String? selectedGenreId;

  GenreSunburstState copyWith({
    List<GenreSunburstNode>? roots,
    bool? isLoading,
    String? error,
    String? selectedGenreId,
    bool clearError = false,
    bool clearSelection = false,
  }) {
    return GenreSunburstState(
      roots: roots ?? this.roots,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedGenreId:
          clearSelection ? null : (selectedGenreId ?? this.selectedGenreId),
    );
  }
}

class GenreSunburstNotifier extends StateNotifier<GenreSunburstState> {
  GenreSunburstNotifier(this._api) : super(const GenreSunburstState());

  final GenreApi _api;

  Future<void> loadTree() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final roots = await _api.fetchSunburstTree();
      state = state.copyWith(roots: roots, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void selectGenre(String? genreId) {
    if (genreId == state.selectedGenreId) {
      state = state.copyWith(clearSelection: true);
    } else {
      state = state.copyWith(selectedGenreId: genreId);
    }
  }
}

final genreSunburstProvider = StateNotifierProvider.autoDispose<
    GenreSunburstNotifier, GenreSunburstState>(
  (ref) {
    final api = ref.watch(genreApiProvider);
    final notifier = GenreSunburstNotifier(api);
    notifier.loadTree();
    return notifier;
  },
);
