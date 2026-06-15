import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

/// Map section: shows an interactive map preview if coordinates are available.
///
/// Uses [RaverMapView] which renders:
/// - Apple Maps (MapKit) on iOS
/// - OpenStreetMap (flutter_map) on Android / HarmonyOS
class EventMapSection extends StatelessWidget {
  const EventMapSection({
    super.key,
    required this.event,
  });

  final WebEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final location = event.location;

    if (location == null ||
        location.latitude == null ||
        location.longitude == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lt('场馆地图', 'Venue Map', '会場マップ'),
              style: RaverTypography.title(size: 16, color: theme.primaryText),
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.cardBorder),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 32,
                      color: theme.secondaryText.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lt('暂无位置信息',
                          'No location info available',
                          '位置情報がありません'),
                      style: RaverTypography.body(
                        size: 14,
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final lat = location.latitude!;
    final lng = location.longitude!;
    final venueName = location.name.isNotEmpty ? location.name : event.name;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lt('场馆地图', 'Venue Map', '会場マップ'),
            style: RaverTypography.title(size: 16, color: theme.primaryText),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              _showFullScreenMap(context, lat, lng, venueName);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AbsorbPointer(
                      child: RaverMapView(
                        latitude: lat,
                        longitude: lng,
                        markerLabel: venueName,
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.fullscreen,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lt('全屏查看', 'Full Screen', 'フルスクリーン'),
                              style: RaverTypography.caption(
                                color: Colors.white,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenMap(
    BuildContext context,
    double lat,
    double lng,
    String venueName,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              lt('场馆地图', 'Venue Map', '会場マップ'),
              style: RaverTypography.title(color: Colors.white),
            ),
          ),
          body: RaverMapView(
            latitude: lat,
            longitude: lng,
            markerLabel: venueName,
          ),
        ),
      ),
    );
  }
}
