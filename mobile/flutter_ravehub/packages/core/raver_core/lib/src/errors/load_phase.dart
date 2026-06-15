import 'package:meta/meta.dart';

/// A sealed representation of the lifecycle phases a data-loading operation
/// passes through.
///
/// Mirrors the iOS `LoadPhase` enum in `LoadPhase.swift`, with the addition
/// of a generic [data] payload on [LoadPhaseSuccess] so that Flutter widgets
/// can pattern-match directly on the phase without a separate data holder.
///
/// Usage:
/// ```dart
/// switch (phase) {
///   case LoadPhaseIdle():        // show placeholder
///   case LoadPhaseLoading():     // show spinner
///   case LoadPhaseSuccess(:final data): // render data
///   case LoadPhaseEmpty():       // show empty-state illustration
///   case LoadPhaseFailure(:final error): // show error + retry
///   case LoadPhaseOffline(:final error): // show offline banner
/// }
/// ```
@immutable
sealed class LoadPhase<T> {
  const LoadPhase();

  /// No load has been attempted yet.
  const factory LoadPhase.idle() = LoadPhaseIdle<T>;

  /// The first (or only) load is in progress.
  const factory LoadPhase.initialLoading() = LoadPhaseLoading<T>;

  /// Data was loaded successfully.
  const factory LoadPhase.success(T data) = LoadPhaseSuccess<T>;

  /// The load succeeded but the result set is empty.
  const factory LoadPhase.empty() = LoadPhaseEmpty<T>;

  /// The load failed with an [error] message.
  const factory LoadPhase.failure(String error) = LoadPhaseFailure<T>;

  /// The device appears to be offline.
  const factory LoadPhase.offline(String error) = LoadPhaseOffline<T>;

  /// The human-readable error message, if this phase carries one.
  String? get errorMessage => null;

  /// Whether the UI should block interaction (e.g. show a full-screen
  /// loading indicator or placeholder).
  bool get isBlocking => false;
}

/// {@macro load_phase.idle}
class LoadPhaseIdle<T> extends LoadPhase<T> {
  const LoadPhaseIdle();

  @override
  bool get isBlocking => true;

  @override
  String toString() => 'LoadPhase.idle';
}

/// {@macro load_phase.initialLoading}
class LoadPhaseLoading<T> extends LoadPhase<T> {
  const LoadPhaseLoading();

  @override
  bool get isBlocking => true;

  @override
  String toString() => 'LoadPhase.initialLoading';
}

/// {@macro load_phase.success}
class LoadPhaseSuccess<T> extends LoadPhase<T> {
  const LoadPhaseSuccess(this.data);

  /// The successfully loaded payload.
  final T data;

  @override
  String toString() => 'LoadPhase.success($data)';
}

/// {@macro load_phase.empty}
class LoadPhaseEmpty<T> extends LoadPhase<T> {
  const LoadPhaseEmpty();

  @override
  String toString() => 'LoadPhase.empty';
}

/// {@macro load_phase.failure}
class LoadPhaseFailure<T> extends LoadPhase<T> {
  const LoadPhaseFailure(this.error);

  /// A human-readable description of what went wrong.
  final String error;

  @override
  String? get errorMessage => error;

  @override
  String toString() => 'LoadPhase.failure($error)';
}

/// {@macro load_phase.offline}
class LoadPhaseOffline<T> extends LoadPhase<T> {
  const LoadPhaseOffline(this.error);

  /// A human-readable description of the connectivity issue.
  final String error;

  @override
  String? get errorMessage => error;

  @override
  String toString() => 'LoadPhase.offline($error)';
}
