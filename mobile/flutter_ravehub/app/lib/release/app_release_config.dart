/// Release configuration constants: store URLs, bundle IDs, and support links.
///
/// These values are used across the app for:
/// - Version update dialogs (store URLs for each platform)
/// - Settings / About screens (privacy policy, terms, support email)
/// - Platform-specific identifiers (bundle IDs matching each store listing)
///
/// **Important:** Update the placeholder store IDs (e.g. `id0000000000`,
/// `C0000000`) with real values after each platform's app store submission
/// is accepted.
abstract final class AppReleaseConfig {
  // ---------------------------------------------------------------------------
  // Bundle / package identifiers
  // ---------------------------------------------------------------------------

  /// iOS bundle identifier (CFBundleIdentifier in Info.plist).
  static const iosBundleId = 'com.ravehub.app';

  /// Android application ID (applicationId in build.gradle).
  static const androidPackageName = 'com.ravehub.app';

  /// HarmonyOS bundle name (bundleName in module.json5).
  static const harmonyBundleName = 'com.ravehub.app';

  // ---------------------------------------------------------------------------
  // App Store URLs (fill in after app store submission)
  // ---------------------------------------------------------------------------

  /// iOS App Store product page URL.
  static const iosAppStoreUrl =
      'https://apps.apple.com/app/ravehub/id0000000000';

  /// Google Play Store listing URL.
  static const androidPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.ravehub.app';

  /// Huawei AppGallery listing URL.
  static const harmonyAppGalleryUrl =
      'https://appgallery.huawei.com/#/app/C0000000';

  // ---------------------------------------------------------------------------
  // Support links
  // ---------------------------------------------------------------------------

  /// Privacy policy page URL, shown in Settings and registration flow.
  static const privacyPolicyUrl = 'https://ravehub.top/privacy';

  /// Terms of service page URL, shown in Settings and registration flow.
  static const termsOfServiceUrl = 'https://ravehub.top/terms';

  /// Customer support email address.
  static const supportEmail = 'support@ravehub.top';
}
