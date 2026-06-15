import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

import '../../news/data/news_providers.dart';
import 'dj_api.dart';

final djApiProvider = Provider<DjApi>((ref) {
  return DjApi(ref.watch(dioProvider));
});

class DjsListState {
  const DjsListState({
    this.djs = const [],
    this.spotlightDJs = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.hasLoaded = false,
  });

  final List<WebDJ> djs;
  final List<WebDJ> spotlightDJs;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final bool hasLoaded;

  List<WebDJ> get carouselDJs {
    if (spotlightDJs.isNotEmpty) return spotlightDJs;
    final sorted = List<WebDJ>.from(djs)
      ..sort((a, b) => b.followerCount.compareTo(a.followerCount));
    return sorted;
  }

  DjsListState copyWith({
    List<WebDJ>? djs,
    List<WebDJ>? spotlightDJs,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    bool? hasLoaded,
    bool clearError = false,
  }) {
    return DjsListState(
      djs: djs ?? this.djs,
      spotlightDJs: spotlightDJs ?? this.spotlightDJs,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasLoaded: hasLoaded ?? this.hasLoaded,
    );
  }
}

class DjsListNotifier extends StateNotifier<DjsListState> {
  final DjApi _api;

  DjsListNotifier(this._api) : super(const DjsListState());

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
      final results = await Future.wait([
        _api.fetchDJs(page: 1, limit: 25, sortBy: 'random'),
        _api.fetchSpotlightDJs(limit: 10),
      ]);
      final hotPage = results[0] as BFFListPage<WebDJ>;
      final spotlight = results[1] as List<WebDJ>;
      state = state.copyWith(
        djs: hotPage.items,
        spotlightDJs: _deduplicate(spotlight),
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

  List<WebDJ> _deduplicate(List<WebDJ> items) {
    final seen = <String>{};
    return items.where((dj) => seen.add(dj.id)).toList();
  }
}

final djsListProvider =
    StateNotifierProvider.autoDispose<DjsListNotifier, DjsListState>((ref) {
  return DjsListNotifier(ref.watch(djApiProvider));
});

class DjDetailState {
  const DjDetailState({
    this.dj,
    this.sets = const [],
    this.isLoading = false,
    this.isFollowLoading = false,
    this.errorMessage,
    this.selectedTab = DjDetailTab.intro,
  });

  final WebDJ? dj;
  final List<WebDJSet> sets;
  final bool isLoading;
  final bool isFollowLoading;
  final String? errorMessage;
  final DjDetailTab selectedTab;

  DjDetailState copyWith({
    WebDJ? dj,
    List<WebDJSet>? sets,
    bool? isLoading,
    bool? isFollowLoading,
    String? errorMessage,
    DjDetailTab? selectedTab,
    bool clearError = false,
  }) {
    return DjDetailState(
      dj: dj ?? this.dj,
      sets: sets ?? this.sets,
      isLoading: isLoading ?? this.isLoading,
      isFollowLoading: isFollowLoading ?? this.isFollowLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }
}

enum DjDetailTab { intro, sets }

class DjDetailNotifier extends StateNotifier<DjDetailState> {
  final DjApi _api;
  final String djId;

  DjDetailNotifier(this._api, this.djId) : super(const DjDetailState());

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dj = await _api.fetchDJ(djId);
      state = state.copyWith(dj: dj, isLoading: false);
      _loadSets();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> _loadSets() async {
    try {
      final page = await _api.fetchDJSets(djId, page: 1, limit: 10);
      state = state.copyWith(sets: page.items);
    } catch (_) {}
  }

  void setTab(DjDetailTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  Future<void> toggleFollow() async {
    final dj = state.dj;
    if (dj == null || state.isFollowLoading) return;
    state = state.copyWith(isFollowLoading: true);
    try {
      final updated =
          await _api.toggleFollow(djId, follow: !(dj.isFollowing ?? false));
      state = state.copyWith(dj: updated, isFollowLoading: false);
    } catch (_) {
      state = state.copyWith(isFollowLoading: false);
    }
  }
}

final djDetailProvider = StateNotifierProvider.autoDispose
    .family<DjDetailNotifier, DjDetailState, String>((ref, djId) {
  return DjDetailNotifier(ref.watch(djApiProvider), djId);
});
