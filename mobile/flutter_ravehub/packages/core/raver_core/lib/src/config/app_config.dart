/// The runtime mode of the application, determining which backend service
/// surface is used.
enum AppRuntimeMode {
  /// Use local developer-only overrides instead of the production BFF.
  localDevelopment,

  /// Use the live BFF (backend-for-frontend) service.
  live,
}

/// Central, compile-time-aware configuration for the RaveHub application.
///
/// Mirrors the iOS `AppConfig` enum and exposes the same constants so that
/// both platforms behave identically for a given build flavour.
///
/// This class is not meant to be instantiated -- all members are static.
class AppConfig {
  AppConfig._();

  // ---------------------------------------------------------------------------
  // Runtime mode
  // ---------------------------------------------------------------------------

  /// The current runtime mode.
  ///
  /// Defaults to [AppRuntimeMode.live]. Callers may override this at app
  /// startup (e.g. via a `--dart-define` flag or flavour configuration).
  static AppRuntimeMode runtimeMode = AppRuntimeMode.live;

  // ---------------------------------------------------------------------------
  // Base URLs
  // ---------------------------------------------------------------------------

  /// BFF base URL used in **debug** builds.
  ///
  /// The Flutter migration is validated against the live BFF so debug and
  /// release builds share the same service surface unless a local proxy is
  /// wired in explicitly.
  static const String debugBffBaseUrl = 'https://api.ravehub.top';

  /// BFF base URL used in **release** builds.
  static const String releaseBffBaseUrl = 'https://api.ravehub.top';

  /// Returns the appropriate BFF base URL for the current build mode.
  ///
  /// In debug (assert-enabled) builds this returns [debugBffBaseUrl];
  /// otherwise it returns [releaseBffBaseUrl].
  static String get bffBaseUrl {
    // `kDebugMode` is tree-shaken, but we avoid importing `foundation` here
    // to keep the core package pure Dart.  The assert trick achieves the same
    // compile-time constant-folding.
    var isDebug = false;
    assert(() {
      isDebug = true;
      return true;
    }());
    return isDebug ? debugBffBaseUrl : releaseBffBaseUrl;
  }

  // ---------------------------------------------------------------------------
  // OSS / CDN
  // ---------------------------------------------------------------------------

  /// The Alibaba Cloud OSS bucket host used for all user-uploaded and
  /// system-default assets.
  static const String ossBaseUrl = 'wen-jasonlee.oss-cn-shanghai.aliyuncs.com';

  // ---------------------------------------------------------------------------
  // Default avatars
  // ---------------------------------------------------------------------------

  /// Fallback avatar URL used when the user has not set a profile picture.
  static const String defaultAvatarUrl =
      'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/'
      'user/user-avatar-01.png';

  /// All default user avatar URLs shipped with the app.
  static const List<String> defaultUserAvatarUrls = [
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-01.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-02.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-03.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-04.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-05.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-06.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-07.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-08.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-09.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-10.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-11.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-12.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-13.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-14.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-15.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-16.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-17.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-18.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-19.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-20.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-21.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-22.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-23.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-24.png',
  ];

  /// All default group avatar URLs shipped with the app.
  static const List<String> defaultGroupAvatarUrls = [
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-01.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-02.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-03.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-04.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-05.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-06.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-07.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-08.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-09.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-10.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-11.png',
    'https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-12.png',
  ];

  /// Returns a deterministic default avatar URL for the given [seed] string,
  /// chosen from [pool] using an FNV-1a hash -- identical to the iOS
  /// implementation so both platforms show the same fallback for a given user.
  static String? defaultAvatarUrlFromSeed(String seed, List<String> pool) {
    if (pool.isEmpty) return null;
    final normalized = seed.toLowerCase();
    var hash = 2166136261; // FNV offset basis (32-bit, web-safe)
    const prime = 16777619; // FNV prime (32-bit)
    for (final codeUnit in normalized.runes) {
      hash ^= codeUnit;
      hash = (hash * prime) & 0x7FFFFFFF;
    }
    final index = hash % pool.length;
    return pool[index];
  }
}
