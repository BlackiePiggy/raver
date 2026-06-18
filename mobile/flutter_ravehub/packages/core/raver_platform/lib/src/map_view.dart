import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as apple;

/// Platform-aware map widget.
/// - iOS: Apple Maps (MapKit via apple_maps_flutter)
/// - Android / HarmonyOS: OpenStreetMap (flutter_map)
class RaverMapView extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? markerLabel;
  final double zoom;

  const RaverMapView({
    super.key,
    required this.latitude,
    required this.longitude,
    this.markerLabel,
    this.zoom = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _AppleMapView(
        latitude: latitude,
        longitude: longitude,
        markerLabel: markerLabel,
        zoom: zoom,
      );
    }
    return _OsmMapView(
      latitude: latitude,
      longitude: longitude,
      markerLabel: markerLabel,
      zoom: zoom,
    );
  }
}

// -- iOS: MapKit ---------------------------------------------------------------

class _AppleMapView extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? markerLabel;
  final double zoom;

  const _AppleMapView({
    required this.latitude,
    required this.longitude,
    this.markerLabel,
    required this.zoom,
  });

  @override
  State<_AppleMapView> createState() => _AppleMapViewState();
}

class _AppleMapViewState extends State<_AppleMapView> {
  @override
  Widget build(BuildContext context) {
    final position = apple.CameraPosition(
      target: apple.LatLng(widget.latitude, widget.longitude),
      zoom: widget.zoom,
    );
    final annotations = <apple.Annotation>{};
    if (widget.markerLabel != null) {
      annotations.add(
        apple.Annotation(
          annotationId: apple.AnnotationId('venue'),
          position: apple.LatLng(widget.latitude, widget.longitude),
          infoWindow: apple.InfoWindow(title: widget.markerLabel),
        ),
      );
    }
    return apple.AppleMap(
      initialCameraPosition: position,
      annotations: annotations,
      myLocationEnabled: false,
      compassEnabled: true,
    );
  }
}

// -- Android / HarmonyOS: OpenStreetMap ----------------------------------------

class _OsmMapView extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? markerLabel;
  final double zoom;

  const _OsmMapView({
    required this.latitude,
    required this.longitude,
    this.markerLabel,
    required this.zoom,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return FlutterMap(
      options: MapOptions(
        initialCenter: point,
        initialZoom: zoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ravehub.app',
        ),
        if (markerLabel != null)
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: 40,
                height: 50,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        markerLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    CustomPaint(
                      size: const Size(12, 6),
                      painter: _TrianglePainter(
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        // OSM attribution (required by tile usage policy)
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}
