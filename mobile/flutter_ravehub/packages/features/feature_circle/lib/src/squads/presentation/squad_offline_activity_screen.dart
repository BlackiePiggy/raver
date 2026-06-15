import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

/// Screen showing a single offline activity details.
class SquadOfflineActivityScreen extends StatelessWidget {
  const SquadOfflineActivityScreen({
    super.key,
    required this.activity,
  });

  final SquadOfflineActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final isOngoing = activity.status == 'ongoing';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          lt('线下活动', 'Activity', 'オフライン活動'),
          style: RaverTypography.title(size: 17, color: theme.primaryText),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isOngoing
                    ? Colors.green.withValues(alpha: 0.12)
                    : theme.cardBorder,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isOngoing
                    ? lt('进行中', 'Ongoing', '進行中')
                    : lt('已结束', 'Ended', '終了'),
                style: RaverTypography.label(
                  size: 13,
                  color: isOngoing ? Colors.green : theme.secondaryText,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Event name
            Text(
              activity.eventName,
              style: RaverTypography.headline(color: theme.primaryText)
                  .copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),

            // Time
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: theme.secondaryText),
                const SizedBox(width: 6),
                Text(
                  _formatDateRange(activity.startedAt, activity.endedAt),
                  style: RaverTypography.body(
                    size: 14,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Participants
            Text(
              lt('参与成员', 'Participants', '参加者'),
              style: RaverTypography.title(
                size: 16,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 12),

            if (activity.participants == null ||
                activity.participants!.isEmpty)
              Text(
                lt('暂无参与者', 'No participants', '参加者なし'),
                style: RaverTypography.body(
                  size: 14,
                  color: theme.secondaryText,
                ),
              )
            else
              ...activity.participants!.map(
                (p) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.cardBorder,
                        backgroundImage: p.avatarUrl.isNotEmpty
                            ? NetworkImage(p.avatarUrl)
                            : null,
                        child: p.avatarUrl.isEmpty
                            ? Icon(Icons.person,
                                size: 18, color: theme.secondaryText)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        p.displayName,
                        style: RaverTypography.label(
                          size: 14,
                          color: theme.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatDateRange(String start, String end) {
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      return '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')} '
          '~ ${e.year}-${e.month.toString().padLeft(2, '0')}-${e.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '$start ~ $end';
    }
  }
}
