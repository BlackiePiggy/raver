import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    required this.event,
    required this.onTap,
    super.key,
    this.onFavorite,
  });

  final WebEvent event;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCoverImage(theme),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypePill(theme),
                  const SizedBox(height: 8),
                  Text(
                    event.name,
                    style: RaverTypography.title(
                      size: 16,
                      color: theme.primaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _buildDateRow(theme),
                  if (event.location != null) ...[
                    const SizedBox(height: 4),
                    _buildLocationRow(theme),
                  ],
                  const SizedBox(height: 8),
                  _buildStatsRow(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(RaverThemeData theme) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RemoteCoverImage(
            url: event.coverImageUrl,
            fit: BoxFit.cover,
          ),
          if (onFavorite != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onFavorite,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    event.isFavorited == true
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: event.isFavorited == true
                        ? Colors.redAccent
                        : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypePill(RaverThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _eventTypeLabel(event.eventType),
        style: RaverTypography.caption(
          color: theme.accent,
          weight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDateRow(RaverThemeData theme) {
    return Row(
      children: [
        Icon(Icons.calendar_today, size: 13, color: theme.secondaryText),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _formatDateRange(event.startDate, event.endDate),
            style: RaverTypography.caption(color: theme.secondaryText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(RaverThemeData theme) {
    final loc = event.location!;
    final parts = [loc.name, loc.city, loc.country]
        .where((s) => s.isNotEmpty)
        .toList();

    return Row(
      children: [
        Icon(Icons.location_on_outlined, size: 13, color: theme.secondaryText),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            parts.join(', '),
            style: RaverTypography.caption(color: theme.secondaryText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(RaverThemeData theme) {
    return Row(
      children: [
        Icon(Icons.favorite_border, size: 13, color: theme.secondaryText),
        const SizedBox(width: 3),
        Text(
          '${event.favoriteCount}',
          style: RaverTypography.caption(color: theme.secondaryText),
        ),
        const SizedBox(width: 12),
        Icon(Icons.check_circle_outline, size: 13, color: theme.secondaryText),
        const SizedBox(width: 3),
        Text(
          '${event.checkinCount}',
          style: RaverTypography.caption(color: theme.secondaryText),
        ),
      ],
    );
  }

  static String _eventTypeLabel(String type) => switch (type) {
        'festival' => 'Festival',
        'bar_event' => 'Bar',
        'outdoor_event' => 'Outdoor',
        'club_party' => 'Club',
        'liveshow' => 'Live Show',
        'warehouse' => 'Warehouse',
        'cruise' => 'Cruise',
        _ => type,
      };

  static String _formatDateRange(String start, String end) {
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      final startStr =
          '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
      if (s.year == e.year && s.month == e.month && s.day == e.day) {
        return startStr;
      }
      final endStr =
          '${e.year}-${e.month.toString().padLeft(2, '0')}-${e.day.toString().padLeft(2, '0')}';
      return '$startStr ~ $endStr';
    } catch (_) {
      return '$start ~ $end';
    }
  }
}
