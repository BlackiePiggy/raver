import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:raver_models/raver_models.dart';

import '../data/label_api.dart';

class LabelsState {
  const LabelsState({
    this.labels = const [],
    this.isLoading = false,
    this.error,
  });

  final List<LearnLabel> labels;
  final bool isLoading;
  final String? error;

  LabelsState copyWith({
    List<LearnLabel>? labels,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return LabelsState(
      labels: labels ?? this.labels,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LabelsNotifier extends StateNotifier<LabelsState> {
  LabelsNotifier(this._api) : super(const LabelsState()) {
    loadLabels();
  }

  final LabelApi _api;

  Future<void> loadLabels() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final labels = await _api.fetchLabels();
      state = state.copyWith(labels: labels, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

final labelsProvider =
    StateNotifierProvider.autoDispose<LabelsNotifier, LabelsState>(
  (ref) {
    final api = ref.watch(labelApiProvider);
    return LabelsNotifier(api);
  },
);

class LabelDetailState {
  const LabelDetailState({this.label, this.isLoading = false, this.error});

  final LearnLabel? label;
  final bool isLoading;
  final String? error;
}

class LabelDetailNotifier extends StateNotifier<LabelDetailState> {
  LabelDetailNotifier(this._api, this._labelId)
      : super(const LabelDetailState()) {
    _load();
  }

  final LabelApi _api;
  final String _labelId;

  Future<void> _load() async {
    state = const LabelDetailState(isLoading: true);
    try {
      final label = await _api.fetchLabelDetail(_labelId);
      state = LabelDetailState(label: label);
    } catch (e) {
      state = LabelDetailState(error: e.toString());
    }
  }

  Future<void> retry() => _load();
}

final labelDetailProvider = StateNotifierProvider.autoDispose
    .family<LabelDetailNotifier, LabelDetailState, String>(
  (ref, labelId) {
    final api = ref.watch(labelApiProvider);
    return LabelDetailNotifier(api, labelId);
  },
);
