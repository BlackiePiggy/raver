import 'package:flutter/material.dart';
import 'package:raver_core/raver_core.dart';
import 'package:raver_i18n/raver_i18n.dart';

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

  /// Data fetch failed because the network appears to be offline.
  const factory LoadPhase.offline(Object error) = LoadPhaseOffline<T>;

  /// Data fetch succeeded but the result set is empty.
  const factory LoadPhase.empty() = LoadPhaseEmpty<T>;

  /// Maps raw repository/API errors into a display phase.
  static LoadPhase<T> fromError<T>(Object error) {
    if (_isOfflineError(error)) return LoadPhase<T>.offline(error);
    return LoadPhase<T>.failure(_displayError(error));
  }
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

class LoadPhaseOffline<T> extends LoadPhase<T> {
  const LoadPhaseOffline(this.error);
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
      LoadPhaseLoading<T>() => onLoading?.call() ??
          const Center(child: CircularProgressIndicator.adaptive()),
      LoadPhaseSuccess<T>(:final data) => onSuccess(data),
      LoadPhaseFailure<T>(:final error) => onFailure?.call(error) ??
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
      LoadPhaseOffline<T>(:final error) => onFailure?.call(error) ??
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _displayError(error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
      LoadPhaseEmpty<T>() => onEmpty?.call() ??
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No data'),
            ),
          ),
    };
  }
}

String _displayError(Object error) {
  if (error is MessageError) return error.text;
  if (error is UnauthorizedError) {
    return lt('请先登录后重试。', 'Please log in and try again.', 'ログインしてから再試行してください。');
  }
  if (error is SessionExpiredError || error is AccountInactiveError) {
    return lt(
      '登录状态已失效，请重新登录。',
      'Session expired. Please log in again.',
      'ログイン状態が無効です。再度ログインしてください。',
    );
  }
  return error.toString();
}

bool _isOfflineError(Object error) {
  if (error is LoadPhaseOffline) return true;
  final text = error.toString().toLowerCase();
  return text.contains('connection error') ||
      text.contains('connectionerror') ||
      text.contains('connection timeout') ||
      text.contains('connectiontimeout') ||
      text.contains('receivetimeout') ||
      text.contains('sendtimeout') ||
      text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('networkerror') ||
      text.contains('xmlhttprequest error');
}
