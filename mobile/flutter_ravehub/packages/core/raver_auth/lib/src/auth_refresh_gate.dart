import 'dart:async';

/// Deduplicates concurrent token-refresh requests.
///
/// Ported from iOS `AppAuthRefreshGate`. When multiple 401 responses arrive at
/// the same time, only a single refresh call is made. All callers share the
/// result of that one in-flight request.
///
/// ```dart
/// final gate = AuthRefreshGate();
///
/// // Multiple concurrent calls collapse into one actual refresh:
/// final results = await Future.wait([
///   gate.refreshIfNeeded(() => _performRefresh()),
///   gate.refreshIfNeeded(() => _performRefresh()),
/// ]);
/// ```
class AuthRefreshGate {
  /// The completer for the currently in-flight refresh, if any.
  Completer<bool>? _activeRefresh;

  /// Whether a token refresh is currently in progress.
  bool get isRefreshing => _activeRefresh != null;

  /// Executes [doRefresh] if no refresh is already in flight. Otherwise,
  /// returns the result of the existing refresh.
  ///
  /// [doRefresh] should return `true` if the refresh succeeded and `false`
  /// otherwise. Errors thrown by [doRefresh] are propagated to all waiters.
  Future<bool> refreshIfNeeded(Future<bool> Function() doRefresh) async {
    if (_activeRefresh != null) {
      return _activeRefresh!.future;
    }

    _activeRefresh = Completer<bool>();

    try {
      final result = await doRefresh();
      _activeRefresh!.complete(result);
      return result;
    } catch (e) {
      _activeRefresh!.completeError(e);
      rethrow;
    } finally {
      _activeRefresh = null;
    }
  }
}
