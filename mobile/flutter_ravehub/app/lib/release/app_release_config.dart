/// Release configuration constants: store URLs, bundle IDs, and support links.
///
/// These values are used across the app for:
/// - Version update dialogs (store URLs for each platform)
/// - Settings / About screens (privacy policy, terms, support email)
/// - Platform-specific identifiers (bundle IDs matching each store listing)
///
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
  // App Store URLs
  // ---------------------------------------------------------------------------

  /// iOS App Store product page URL.
  ///
  /// Keep this `null` until Apple assigns the production listing URL.
  static const String? iosAppStoreUrl = null;

  /// Google Play Store listing URL.
  static const String androidPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.ravehub.app';

  /// Huawei AppGallery listing URL.
  ///
  /// Keep this `null` until AppGallery assigns the production listing URL.
  static const String? harmonyAppGalleryUrl = null;

  // ---------------------------------------------------------------------------
  // Support links
  // ---------------------------------------------------------------------------

  /// Privacy policy page URL, shown in Settings and registration flow.
  static const privacyPolicyUrl = 'https://ravehub.top/legal/privacy';

  /// Terms of service page URL, shown in Settings and registration flow.
  static const termsOfServiceUrl = 'https://ravehub.top/legal/terms';

  /// Customer support email address.
  static const supportEmail = 'support@ravehub.top';
}
