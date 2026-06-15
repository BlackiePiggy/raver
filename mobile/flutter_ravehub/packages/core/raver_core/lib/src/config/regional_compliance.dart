/// The age classification of a user, used for regional compliance and
/// content-gating decisions.
///
/// Mirrors the iOS `UserAgeBand` enum in `AppConfig.swift`.
enum UserAgeBand {
  /// The user is below the minimum age threshold (typically 13).
  under13,

  /// The user is above the minimum age but below the adult threshold
  /// (typically 18).
  minor,

  /// The user is at or above the adult age threshold.
  adult,

  /// The user's age is not yet known (e.g. before age declaration).
  unknown,
}
