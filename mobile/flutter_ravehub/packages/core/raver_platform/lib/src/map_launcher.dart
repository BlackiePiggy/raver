import 'package:flutter/foundation.dart';
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final appleMapsUri = appleMapsCoordinateUri(
        latitude: latitude,
        longitude: longitude,
        label: label,
      );
      if (await canLaunchUrl(appleMapsUri)) {
        await launchUrl(appleMapsUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final geoUri = androidGeoCoordinateUri(
        latitude: latitude,
        longitude: longitude,
        label: label,
      );
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
    final webUri = googleMapsSearchUri(query: '$latitude,$longitude');
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  /// Opens an external map app/search page for a free-form address or venue.
  static Future<void> openSearch({required String query}) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      throw ArgumentError.value(query, 'query', 'Map query cannot be empty');
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final appleMapsUri = appleMapsSearchUri(query: trimmedQuery);
      if (await canLaunchUrl(appleMapsUri)) {
        await launchUrl(appleMapsUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final webUri = googleMapsSearchUri(query: trimmedQuery);
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  /// Opens turn-by-turn directions for a free-form destination.
  ///
  /// When [originQuery] is null or blank, the native maps app/browser uses the
  /// user's current location as the origin.
  static Future<void> openRoute({
    String? originQuery,
    required String destinationQuery,
  }) async {
    final destination = destinationQuery.trim();
    if (destination.isEmpty) {
      throw ArgumentError.value(
        destinationQuery,
        'destinationQuery',
        'Route destination cannot be empty',
      );
    }

    final origin = originQuery?.trim();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final appleMapsUri = appleMapsRouteUri(
        originQuery: origin?.isEmpty ?? true ? null : origin,
        destinationQuery: destination,
      );
      if (await canLaunchUrl(appleMapsUri)) {
        await launchUrl(appleMapsUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final webUri = googleMapsRouteUri(
      originQuery: origin?.isEmpty ?? true ? null : origin,
      destinationQuery: destination,
    );
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  static Uri appleMapsCoordinateUri({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    final queryParameters = <String, String>{
      'll': '$latitude,$longitude',
      if (label != null && label.trim().isNotEmpty) 'q': label.trim(),
    };
    return Uri.https('maps.apple.com', '/', queryParameters);
  }

  static Uri androidGeoCoordinateUri({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    if (label == null || label.trim().isEmpty) {
      return Uri.parse('geo:$latitude,$longitude');
    }
    final encodedLabel = Uri.encodeComponent(label.trim());
    return Uri.parse(
      'geo:$latitude,$longitude?q=$latitude,$longitude($encodedLabel)',
    );
  }

  static Uri appleMapsSearchUri({required String query}) =>
      Uri.https('maps.apple.com', '/', {'q': query.trim()});

  static Uri appleMapsRouteUri({
    String? originQuery,
    required String destinationQuery,
  }) {
    final origin = originQuery?.trim();
    return Uri.https('maps.apple.com', '/', {
      if (origin != null && origin.isNotEmpty) 'saddr': origin,
      'daddr': destinationQuery.trim(),
      'dirflg': 'd',
    });
  }

  static Uri googleMapsSearchUri({required String query}) => Uri.https(
    'www.google.com',
    '/maps/search/',
    {'api': '1', 'query': query.trim()},
  );

  static Uri googleMapsRouteUri({
    String? originQuery,
    required String destinationQuery,
  }) {
    final origin = originQuery?.trim();
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      if (origin != null && origin.isNotEmpty) 'origin': origin,
      'destination': destinationQuery.trim(),
      'travelmode': 'driving',
    });
  }

  /// Backwards-compatible alias for [openInMaps].
  static Future<void> launchNavigation({
    required double latitude,
    required double longitude,
    String? label,
  }) => openInMaps(latitude: latitude, longitude: longitude, label: label);
}
