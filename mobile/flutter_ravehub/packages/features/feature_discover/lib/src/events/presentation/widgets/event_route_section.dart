import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';
import 'package:raver_platform/raver_platform.dart';

/// Route section: shows venue address and a "Navigate" button.
class EventRouteSection extends StatelessWidget {
  const EventRouteSection({
    super.key,
    required this.event,
  });

  final WebEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final location = event.location;

    if (location == null) {
      return const SizedBox.shrink();
    }

    final hasCoords =
        location.latitude != null && location.longitude != null;

    final addressParts = [
      location.name,
      location.address,
      location.city,
      location.country,
    ].where((s) => s.isNotEmpty).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lt('路线规划', 'Route', 'ルート案内'),
            style: RaverTypography.title(size: 16, color: theme.primaryText),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 18,
                      color: theme.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        addressParts.join(', '),
                        style: RaverTypography.body(
                          size: 14,
                          color: theme.primaryText,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (hasCoords) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      MapLauncher.openInMaps(
                        latitude: location.latitude!,
                        longitude: location.longitude!,
                        label: location.name,
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.navigation_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            lt('导航到此', 'Navigate', 'ナビ開始'),
                            style: RaverTypography.label(
                              size: 14,
                              color: Colors.white,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
