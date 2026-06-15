// HarmonyOS build configuration notes.
//
// To build the HAP (HarmonyOS Application Package):
// 1. Install DevEco Studio >= 5.0
// 2. Run: flutter build hap --release
// 3. Sign with HarmonyOS certificate via DevEco Studio
//
// Required native adaptations in entry/src/main/ets/:
//   - PushKitAbility.ets: implements Push Kit token retrieval + message forwarding
//   - MapAbility.ets: opens Petal Maps/AutoNavi for navigation
//   - module.json5: declares appLinks skills for ravehub.top deep linking
//
// HarmonyOS-specific package overrides (add to app/pubspec.yaml when targeting OHOS):
//   google_maps_flutter: NOT used -> inline maps use flutter_map (OSM) on Android/HarmonyOS,
//                        and apple_maps_flutter (MapKit) on iOS
//   firebase_messaging: NOT supported -> use HarmonyPushAdapter (this package)
//   firebase_auth: NOT supported -> use SMS/email auth only
//
// Minimum API version: API Level 12 (HarmonyOS 4.2)
// Target API version: API Level 14 (HarmonyOS 5.0)

/// Constants for HarmonyOS build and runtime configuration.
///
/// These values are used both as documentation for the native HarmonyOS project
/// setup and as runtime references for Dart-side platform channel names and
/// feature gating.
///
/// The HAP (HarmonyOS Application Package) build process:
/// 1. DevEco Studio >= 5.0 is required for building.
/// 2. `flutter build hap --release` generates the unsigned HAP.
/// 3. Signing is done through DevEco Studio's built-in signing wizard.
///
/// Native adaptations required in `entry/src/main/ets/`:
/// - `PushKitAbility.ets`: Push Kit token retrieval + message forwarding to Flutter.
/// - `MapAbility.ets`: Opens Petal Maps or AutoNavi for navigation intents.
/// - `module.json5`: Declares `appLinks` skills for `ravehub.top` deep linking.
///
/// Package compatibility notes:
/// - `google_maps_flutter` is **not used**. Inline maps use `flutter_map`
///   (OpenStreetMap tiles) on Android/HarmonyOS and `apple_maps_flutter`
///   (MapKit) on iOS. For external navigation, use `MapLauncher` which
///   invokes Petal Maps / AutoNavi via the [mapChannel] method channel.
/// - `firebase_messaging` is **not supported**. Use `HarmonyPushAdapter` via
///   the [pushKitChannel] method channel.
/// - `firebase_auth` is **not supported**. Fall back to SMS / email auth flows.
abstract final class HarmonyConfig {
  /// Minimum HarmonyOS API level required to run the app.
  /// Corresponds to HarmonyOS 4.2.
  static const minApiLevel = 12;

  /// Target HarmonyOS API level for the build.
  /// Corresponds to HarmonyOS 5.0.
  static const targetApiLevel = 14;

  /// HAP bundle name — must match the `bundleName` field in `module.json5`.
  static const bundleName = 'com.ravehub.app';

  /// Method channel name for HarmonyOS Push Kit communication.
  /// The native side registers this channel in `PushKitAbility.ets`.
  static const pushKitChannel = 'com.ravehub.push/harmony';

  /// Method channel name for HarmonyOS map navigation.
  /// The native side registers this channel in `MapAbility.ets`.
  static const mapChannel = 'com.ravehub.map/harmony';

  /// DevEco Studio minimum version required for building the HAP.
  static const minDevEcoVersion = '5.0';

  /// Deep link host used for HarmonyOS App Links configuration.
  static const deepLinkHost = 'ravehub.top';
}
