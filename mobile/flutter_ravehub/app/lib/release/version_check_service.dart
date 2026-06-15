import 'package:dio/dio.dart';

/// Remote version information returned by `GET /v1/app/version`.
///
/// The server provides a minimum required version (below which the app must
/// be force-updated) and the latest available version (which triggers a soft
/// update prompt).
class VersionInfo {
  /// The lowest version that the server still supports.
  /// If the running app is older than this, a blocking upgrade dialog is shown.
  final String minimumVersion;

  /// The most recent version available in the stores.
  /// If the running app is older than this (but newer than [minimumVersion]),
  /// a dismissable upgrade prompt is shown.
  final String latestVersion;

  /// Store URL for the current platform (App Store / Play Store / AppGallery).
  final String? updateUrl;

  /// Human-readable release notes for the latest version.
  final String? releaseNotes;

  const VersionInfo({
    required this.minimumVersion,
    required this.latestVersion,
    this.updateUrl,
    this.releaseNotes,
  });

  /// Parses a [VersionInfo] from the JSON envelope returned by the BFF.
  factory VersionInfo.fromJson(Map<String, dynamic> json) => VersionInfo(
        minimumVersion: json['minimumVersion'] as String,
        latestVersion: json['latestVersion'] as String,
        updateUrl: json['updateUrl'] as String?,
        releaseNotes: json['releaseNotes'] as String?,
      );
}

/// Service that checks the BFF for app version requirements.
///
/// Usage:
/// ```dart
/// final service = VersionCheckService(dio);
/// final info = await service.checkVersion();
/// if (info != null) {
///   final isForced = VersionCheckService.isOlderThan(currentVersion, info.minimumVersion);
///   // show dialog...
/// }
/// ```
///
/// The check is non-blocking: if the network request fails for any reason the
/// method returns `null` so the app continues normally.
class VersionCheckService {
  final Dio _dio;

  VersionCheckService(this._dio);

  /// Fetches the latest version requirements from the server.
  ///
  /// Returns `null` if the request fails (network error, server error, etc.).
  /// Version checks are non-critical and must never block the user from using
  /// the app.
  Future<VersionInfo?> checkVersion() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/app/version');
      final data = response.data;
      if (data == null) return null;
      return VersionInfo.fromJson(data);
    } catch (_) {
      return null; // Non-critical -- don't block app on version check failure
    }
  }

  /// Returns `true` if [versionA] is strictly older than [versionB] using
  /// semantic version comparison (major.minor.patch).
  ///
  /// Missing segments are treated as `0`, so `'1.2'` is equivalent to `'1.2.0'`.
  ///
  /// Examples:
  /// ```dart
  /// isOlderThan('1.0.0', '1.0.1') == true
  /// isOlderThan('1.0.1', '1.0.0') == false
  /// isOlderThan('1.0.0', '1.0.0') == false
  /// isOlderThan('2.0.0', '1.9.9') == false
  /// ```
  static bool isOlderThan(String versionA, String versionB) {
    final a = versionA.split('.').map(int.parse).toList();
    final b = versionB.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      final ai = i < a.length ? a[i] : 0;
      final bi = i < b.length ? b[i] : 0;
      if (ai < bi) return true;
      if (ai > bi) return false;
    }
    return false;
  }
}
