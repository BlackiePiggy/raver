import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

import '../data/organizer_api.dart';

class OrganizersState {
  const OrganizersState({
    this.festivals = const [],
    this.isLoading = false,
    this.error,
  });

  final List<LearnFestival> festivals;
  final bool isLoading;
  final String? error;

  OrganizersState copyWith({
    List<LearnFestival>? festivals,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OrganizersState(
      festivals: festivals ?? this.festivals,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OrganizersNotifier extends StateNotifier<OrganizersState> {
  OrganizersNotifier(this._api) : super(const OrganizersState()) {
    loadFestivals();
  }

  final OrganizerApi _api;

  Future<void> loadFestivals() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final festivals = await _api.fetchFestivals();
      state = state.copyWith(festivals: festivals, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

final organizersProvider =
    StateNotifierProvider.autoDispose<OrganizersNotifier, OrganizersState>(
  (ref) {
    final api = ref.watch(organizerApiProvider);
    return OrganizersNotifier(api);
  },
);

class FestivalDetailState {
  const FestivalDetailState({
    this.festival,
    this.isLoading = false,
    this.isFollowLoading = false,
    this.error,
    this.followError,
  });

  final LearnFestival? festival;
  final bool isLoading;
  final bool isFollowLoading;
  final String? error;

  final String? followError;

  FestivalDetailState copyWith({
    LearnFestival? festival,
    bool? isLoading,
    bool? isFollowLoading,
    String? error,
    String? followError,
    bool clearError = false,
    bool clearFollowError = false,
  }) {
    return FestivalDetailState(
      festival: festival ?? this.festival,
      isLoading: isLoading ?? this.isLoading,
      isFollowLoading: isFollowLoading ?? this.isFollowLoading,
      error: clearError ? null : (error ?? this.error),
      followError: clearFollowError ? null : (followError ?? this.followError),
    );
  }
}

class FestivalDetailNotifier extends StateNotifier<FestivalDetailState> {
  FestivalDetailNotifier(this._api, this._festivalId)
      : super(const FestivalDetailState()) {
    _load();
  }

  final OrganizerApi _api;
  final String _festivalId;

  Future<void> _load() async {
    state = const FestivalDetailState(isLoading: true);
    try {
      final festival = await _api.fetchFestivalDetail(_festivalId);
      state = FestivalDetailState(festival: festival);
      await _syncFollowPreference();
    } catch (e) {
      state = FestivalDetailState(error: e.toString());
    }
  }

  Future<void> retry() => _load();

  Future<void> _syncFollowPreference() async {
    final festival = state.festival;
    if (festival == null) return;
    try {
      final preference = await _api.fetchFollowedBrandUpdatePreference();
      state = state.copyWith(
        festival: festival.copyWith(
          isFollowing: preference.watchedBrandIds.contains(festival.id),
        ),
        clearFollowError: true,
      );
    } catch (_) {
      // Detail content remains usable when the authenticated preference endpoint
      // is unavailable, for example before login.
    }
  }

  Future<void> toggleFollow() async {
    final festival = state.festival;
    if (festival == null || state.isFollowLoading) return;
    state = state.copyWith(isFollowLoading: true, clearFollowError: true);
    try {
      final updated = await _api.toggleFestivalFollow(festival);
      state = state.copyWith(festival: updated, isFollowLoading: false);
    } catch (e) {
      state = state.copyWith(
        isFollowLoading: false,
        followError: e.toString(),
      );
    }
  }
}

final festivalDetailProvider = StateNotifierProvider.autoDispose
    .family<FestivalDetailNotifier, FestivalDetailState, String>(
  (ref, festivalId) {
    final api = ref.watch(organizerApiProvider);
    return FestivalDetailNotifier(api, festivalId);
  },
);
