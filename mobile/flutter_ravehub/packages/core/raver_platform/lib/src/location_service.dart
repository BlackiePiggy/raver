import 'package:geolocator/geolocator.dart';

/// Provides location access using the [geolocator] package.
///
/// Handles permission checks internally so callers get a simple API.
/// Modelled after the iOS `AppLocationProvider`.
class LocationService {
  /// Convenience static accessor used by older feature code.
  static Future<Position?> getCurrentPosition() =>
      LocationService().currentPosition();

  /// Returns the device's current position, or `null` if location services
  /// are disabled or permission is denied.
  Future<Position?> currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on Exception {
      return null;
    }
  }

  /// Whether the platform location services are enabled (GPS / network).
  Future<bool> isLocationEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Emits a [Position] every time the device moves at least
  /// [distanceFilter] metres, polled roughly at [interval].
  ///
  /// The stream will emit an error if permissions are denied.
  Stream<Position> getPositionStream({
    Duration interval = const Duration(seconds: 5),
    double distanceFilter = 10,
  }) {
    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter.toInt(),
      timeLimit: interval,
    );

    return Geolocator.getPositionStream(locationSettings: settings);
  }
}
