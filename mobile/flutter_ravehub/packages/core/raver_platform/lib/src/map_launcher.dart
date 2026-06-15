import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Launches external map applications for turn-by-turn navigation.
///
/// This class opens the **native maps app** for navigation; it does NOT render
/// inline maps. For inline/embedded maps, see [RaverMapView] which uses:
/// - iOS: Apple Maps (MapKit via `apple_maps_flutter`)
/// - Android / HarmonyOS: OpenStreetMap tiles (via `flutter_map`)
///
/// Platform-specific external map launching:
/// - iOS: Opens Apple Maps (Maps.app) via `maps.apple.com` URL scheme.
/// - Android: Opens Google Maps / default maps app via `geo:` intent.
/// - HarmonyOS: Opens Petal Maps (`petalmaps://`) or AutoNavi (`androidamap://`).
///   When the Flutter HarmonyOS SDK exposes `Platform.isHarmonyOS`, add
///   a dedicated branch in [openInMaps].
class MapLauncher {
  const MapLauncher._();

  /// Opens the native maps app for the current platform at the given
  /// [latitude] / [longitude].
  ///
  /// On iOS it tries Apple Maps first; on Android it tries Google Maps.
  /// Falls back to opening Google Maps in the browser if the native app
  /// cannot be launched.
  static Future<void> openInMaps({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final encodedLabel = label != null ? Uri.encodeComponent(label) : '';
    final query = label != null ? '&q=$encodedLabel' : '';

    if (Platform.isIOS) {
      // Apple Maps URL scheme.
      final appleMapsUri = Uri.parse(
        'https://maps.apple.com/?ll=$latitude,$longitude$query',
      );
      if (await canLaunchUrl(appleMapsUri)) {
        await launchUrl(appleMapsUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (Platform.isAndroid) {
      // Android geo intent -- opens the default maps app.
      final geoUri = label != null
          ? Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude($encodedLabel)')
          : Uri.parse('geo:$latitude,$longitude');
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // -----------------------------------------------------------------------
    // HarmonyOS: Use Petal Maps or AutoNavi (高德) deep links.
    //
    // When the Flutter HarmonyOS SDK exposes a platform check (e.g.
    // Platform.isHarmonyOS or an environment variable), add:
    //
    //   if (Platform.isHarmonyOS) {
    //     // Petal Maps deep link:
    //     //   petalmaps://navigation?daddr=$latitude,$longitude&type=drive
    //     // AutoNavi (高德):
    //     //   androidamap://navi?sourceApplication=ravehub&lat=$latitude&lon=$longitude&dev=0
    //     // Web fallback for Petal Maps:
    //     //   https://maps.huawei.com/?ll=$latitude,$longitude
    //     // Web fallback for AutoNavi:
    //     //   https://uri.amap.com/marker?position=$longitude,$latitude&name=$encodedLabel
    //     final petalUri = Uri.parse(
    //       'petalmaps://navigation?daddr=$latitude,$longitude&type=drive',
    //     );
    //     if (await canLaunchUrl(petalUri)) {
    //       await launchUrl(petalUri, mode: LaunchMode.externalApplication);
    //       return;
    //     }
    //   }
    //
    // Until the official detection API is available, HarmonyOS users fall
    // through to the Google Maps web fallback below, which works in the
    // HarmonyOS browser.
    // -----------------------------------------------------------------------

    // Fallback: open Google Maps in the browser.
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}
