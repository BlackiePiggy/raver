import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import 'event_date_formatter.dart';

const double iosEventRowCoverWidth = 144;
const double iosEventRowCoverHeight = 172;
const double iosEventRowActionColumnWidth = 48;

@visibleForTesting
EventCardVisualStatus resolveEventCardVisualStatus(
  WebEvent event, {
  DateTime? now,
}) {
  final start = _parseEventDate(event.startDate);
  final end = _parseEventDate(event.endDate);
  final reference = now ?? DateTime.now();

  if (start == null && end == null) {
    return EventCardVisualStatus.upcoming;
  }
  if (start != null && reference.isBefore(start)) {
    return EventCardVisualStatus.upcoming;
  }
  if (end != null && reference.isAfter(end)) {
    return EventCardVisualStatus.ended;
  }
  return EventCardVisualStatus.ongoing;
}

enum EventCardVisualStatus {
  upcoming,
  ongoing,
  ended;

  String get label => switch (this) {
        EventCardVisualStatus.upcoming => lt('即将开始', 'Upcoming', 'まもなく開始'),
        EventCardVisualStatus.ongoing => lt('进行中', 'Ongoing', '開催中'),
        EventCardVisualStatus.ended => lt('已结束', 'Ended', '終了'),
      };

  Color get backgroundColor => switch (this) {
        EventCardVisualStatus.upcoming =>
          const Color(0xFFFF9800).withValues(alpha: 0.68),
        EventCardVisualStatus.ongoing =>
          const Color(0xFF4CAF50).withValues(alpha: 0.68),
        EventCardVisualStatus.ended => Colors.black.withValues(alpha: 0.58),
      };

  Color borderColor(RaverThemeData theme) => switch (this) {
        EventCardVisualStatus.upcoming =>
          const Color(0xFFFF9800).withValues(alpha: 0.82),
        EventCardVisualStatus.ongoing =>
          const Color(0xFF4CAF50).withValues(alpha: 0.84),
        EventCardVisualStatus.ended =>
          theme.secondaryText.withValues(alpha: 0.95),
      };
}

class EventCard extends StatelessWidget {
  const EventCard({
    required this.event,
    required this.onTap,
    super.key,
    this.onFavorite,
    this.onShare,
  });

  final WebEvent event;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final status = resolveEventCardVisualStatus(event);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints:
            const BoxConstraints(minHeight: iosEventRowCoverHeight + 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCoverImage(theme, status),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoColumn(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(
    RaverThemeData theme,
    EventCardVisualStatus status,
  ) {
    return SizedBox(
      width: iosEventRowCoverWidth,
      height: iosEventRowCoverHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RemoteCoverImage(
              url: event.coverImageUrl,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 8,
              left: 8,
              child: _buildDateBadge(),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: _buildStatusBadge(theme, status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(RaverThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                event.name,
                style: RaverTypography.title(
                  size: 16,
                  color: theme.primaryText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildActionColumn(theme),
          ],
        ),
        const SizedBox(height: 7),
        Padding(
          padding: const EdgeInsets.only(right: iosEventRowActionColumnWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypePill(theme),
              const SizedBox(height: 7),
              _buildDateRow(theme),
              if (_locationText.isNotEmpty) ...[
                const SizedBox(height: 7),
                _buildLocationRow(theme),
              ],
              const SizedBox(height: 10),
              _buildStatsRow(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionColumn(RaverThemeData theme) {
    if (onFavorite == null && onShare == null) {
      return const SizedBox(width: iosEventRowActionColumnWidth);
    }

    return SizedBox(
      width: iosEventRowActionColumnWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onFavorite != null)
            _CircleActionButton(
              tooltip: event.isFavorited == true
                  ? lt('取消收藏', 'Unfavorite', 'お気に入り解除')
                  : lt('收藏活动', 'Favorite Event', 'イベントをお気に入り'),
              onTap: onFavorite!,
              icon: event.isFavorited == true
                  ? Icons.favorite
                  : Icons.favorite_border,
              color:
                  event.isFavorited == true ? Colors.redAccent : Colors.white,
            ),
          if (onShare != null) ...[
            if (onFavorite != null) const SizedBox(height: 8),
            Semantics(
              button: true,
              label: lt('分享活动', 'Share Event', 'イベントをシェア'),
              child: _CircleActionButton(
                tooltip: lt('分享活动', 'Share Event', 'イベントをシェア'),
                onTap: onShare!,
                icon: Icons.share_outlined,
                color: Colors.white,
              ),
            ),
          ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.calendar_today, size: 13, color: theme.secondaryText),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            EventDateFormatter.range(event),
            style: RaverTypography.caption(color: theme.secondaryText),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(RaverThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on_outlined, size: 13, color: theme.secondaryText),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _locationText,
            style: RaverTypography.caption(color: theme.secondaryText),
            maxLines: 2,
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
        'warehouse_party' => 'Warehouse',
        'tour_special' => 'Tour Special',
        'cruise' => 'Cruise',
        _ => type,
      };

  String get _locationText {
    final loc = event.location;
    if (loc == null) return '';
    return [loc.name, loc.city, loc.country]
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(', ');
  }

  Widget _buildDateBadge() {
    final parts = _parseEventDateParts(event.startDate);
    final month = parts == null ? '--' : _monthBadgeText(parts.month);
    final day = parts?.day.toString() ?? '--';

    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                month,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                day,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    RaverThemeData theme,
    EventCardVisualStatus status,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: ShapeDecoration(
        color: status.backgroundColor,
        shape: StadiumBorder(
          side: BorderSide(color: status.borderColor(theme), width: 0.85),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == EventCardVisualStatus.ongoing) ...[
            const _OngoingStatusBars(),
            const SizedBox(width: 6),
          ],
          Text(
            status.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.tooltip,
    required this.onTap,
    required this.icon,
    required this.color,
  });

  final String tooltip;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _OngoingStatusBars extends StatelessWidget {
  const _OngoingStatusBars();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 13,
      height: 10,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: const [
          _StatusBar(height: 6),
          SizedBox(width: 2),
          _StatusBar(height: 10),
          SizedBox(width: 2),
          _StatusBar(height: 4),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2.6,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(1.3),
      ),
    );
  }
}

class _EventDateParts {
  const _EventDateParts({
    required this.month,
    required this.day,
  });

  final int month;
  final int day;
}

DateTime? _parseEventDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return DateTime.tryParse(trimmed);
}

_EventDateParts? _parseEventDateParts(String value) {
  final parsed = _parseEventDate(value);
  if (parsed != null) {
    return _EventDateParts(month: parsed.month, day: parsed.day);
  }
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value.trim());
  if (match == null) return null;
  return _EventDateParts(
    month: int.parse(match.group(2)!),
    day: int.parse(match.group(3)!),
  );
}

String _monthBadgeText(int month) {
  const labels = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  if (month < 1 || month > 12) return '--';
  return labels[month - 1];
}
