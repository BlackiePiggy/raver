import 'package:flutter_test/flutter_test.dart';
import 'package:raver_platform/raver_platform.dart';

void main() {
  group('MapLauncher URI builders', () {
    test('builds Apple Maps coordinate URI with label', () {
      final uri = MapLauncher.appleMapsCoordinateUri(
        latitude: 31.2304,
        longitude: 121.4737,
        label: 'Shanghai Club',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters['ll'], '31.2304,121.4737');
      expect(uri.queryParameters['q'], 'Shanghai Club');
    });

    test('builds Android geo coordinate URI with encoded label', () {
      final uri = MapLauncher.androidGeoCoordinateUri(
        latitude: 31.2304,
        longitude: 121.4737,
        label: 'Shanghai Club',
      );

      expect(
        uri.toString(),
        'geo:31.2304,121.4737?q=31.2304,121.4737(Shanghai%20Club)',
      );
    });

    test('builds Google Maps route URI without origin', () {
      final uri = MapLauncher.googleMapsRouteUri(
        destinationQuery: 'Shanghai Club',
      );

      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], 'Shanghai Club');
      expect(uri.queryParameters['travelmode'], 'driving');
      expect(uri.queryParameters.containsKey('origin'), isFalse);
    });

    test('builds Apple Maps route URI with origin', () {
      final uri = MapLauncher.appleMapsRouteUri(
        originQuery: 'People Square',
        destinationQuery: 'Shanghai Club',
      );

      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters['saddr'], 'People Square');
      expect(uri.queryParameters['daddr'], 'Shanghai Club');
      expect(uri.queryParameters['dirflg'], 'd');
    });
  });
}
