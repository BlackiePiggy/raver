import 'package:flutter/material.dart';

// =============================================================================
// LoadPhase
// =============================================================================

/// Represents the lifecycle phases of an asynchronous data-loading operation.
///
/// This is a simple sealed class (algebraic data type) that the
/// [LoadPhaseBuilder] widget switches on to display the appropriate UI.
sealed class LoadPhase<T> {
  const LoadPhase();

  /// Data is being fetched for the first time.
  const factory LoadPhase.loading() = LoadPhaseLoading<T>;

  /// Data was fetched successfully.
  const factory LoadPhase.success(T data) = LoadPhaseSuccess<T>;

  /// Data fetch failed.
  const factory LoadPhase.failure(Object error) = LoadPhaseFailure<T>;

  /// Data fetch succeeded but the result set is empty.
  const factory LoadPhase.empty() = LoadPhaseEmpty<T>;
}

class LoadPhaseLoading<T> extends LoadPhase<T> {
  const LoadPhaseLoading();
}

class LoadPhaseSuccess<T> extends LoadPhase<T> {
  const LoadPhaseSuccess(this.data);
  final T data;
}

class LoadPhaseFailure<T> extends LoadPhase<T> {
  const LoadPhaseFailure(this.error);
  final Object error;
}

class LoadPhaseEmpty<T> extends LoadPhase<T> {
  const LoadPhaseEmpty();
}

// =============================================================================
// LoadPhaseBuilder
// =============================================================================

/// A builder widget that maps a [LoadPhase] to one of four child builders.
///
/// ```dart
/// LoadPhaseBuilder<List<Event>>(
///   phase: viewModel.phase,
///   onSuccess: (events) => EventList(events: events),
///   onLoading: () => const EventListSkeleton(),
/// )
/// ```
class LoadPhaseBuilder<T> extends StatelessWidget {
  /// Creates a [LoadPhaseBuilder].
  const LoadPhaseBuilder({
    required this.phase,
    required this.onSuccess,
    super.key,
    this.onLoading,
    this.onFailure,
    this.onEmpty,
  });

  /// The current load phase.
  final LoadPhase<T> phase;

  /// Builder invoked when data is available.
  final Widget Function(T data) onSuccess;

  /// Builder invoked while data is loading. Falls back to a centred
  /// [CircularProgressIndicator] if not provided.
  final Widget Function()? onLoading;

  /// Builder invoked when data loading failed. Falls back to a centred
  /// error icon and message if not provided.
  final Widget Function(Object error)? onFailure;

  /// Builder invoked when the result set is empty. Falls back to a centred
  /// "No data" text if not provided.
  final Widget Function()? onEmpty;

  @override
  Widget build(BuildContext context) {
    return switch (phase) {
      LoadPhaseLoading<T>() =>
        onLoading?.call() ??
            const Center(child: CircularProgressIndicator.adaptive()),
      LoadPhaseSuccess<T>(:final data) => onSuccess(data),
      LoadPhaseFailure<T>(:final error) =>
        onFailure?.call(error) ??
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
      LoadPhaseEmpty<T>() =>
        onEmpty?.call() ??
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No data'),
              ),
            ),
    };
  }
}
