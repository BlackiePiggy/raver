import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// Detail screen showing what changed for a followed entity (event/DJ/brand).
///
/// Displays the entity information, a list of changed fields, and
/// a before/after comparison for each field.
class EntityChangeDetailScreen extends StatelessWidget {
  const EntityChangeDetailScreen({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.changeType,
    required this.summary,
    this.imageUrl,
  });

  final String entityType;
  final String entityId;
  final String entityName;
  final String changeType;
  final String summary;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        title: Text(
          lt('变更详情', 'Change Detail', '変更詳細'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entity header
            _buildEntityHeader(theme),
            const SizedBox(height: 20),
            // Change type and summary
            _buildChangeInfo(theme),
            const SizedBox(height: 24),
            // Placeholder for field-level diff (requires API data)
            _buildDiffSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityHeader(RaverThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: RemoteCoverImage(
                url: imageUrl!,
                width: 56,
                height: 56,
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _entityTypeLabel(entityType),
                    style: RaverTypography.caption(
                      color: theme.accent,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entityName,
                  style: RaverTypography.title(
                    size: 18,
                    color: theme.primaryText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeInfo(RaverThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lt('变更类型', 'Change Type', '変更タイプ'),
          style: RaverTypography.label(
            size: 14,
            color: theme.secondaryText,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _changeTypeColor(changeType).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            changeType,
            style: RaverTypography.label(
              size: 13,
              color: _changeTypeColor(changeType),
              weight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          lt('变更摘要', 'Summary', '変更概要'),
          style: RaverTypography.label(
            size: 14,
            color: theme.secondaryText,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          summary,
          style: RaverTypography.body(size: 14, color: theme.primaryText),
        ),
      ],
    );
  }

  Widget _buildDiffSection(RaverThemeData theme) {
    // Placeholder for per-field before/after comparisons.
    // In a full implementation, the API would return a list of changed fields
    // with their old and new values.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lt('变更字段', 'Changed Fields', '変更フィールド'),
          style: RaverTypography.title(size: 16, color: theme.primaryText),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.cardBorder),
          ),
          child: Column(
            children: [
              Icon(
                Icons.compare_arrows,
                size: 32,
                color: theme.secondaryText.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                lt(
                  '详细变更对比将在此显示',
                  'Detailed field comparison will appear here',
                  '詳細なフィールド比較がここに表示されます',
                ),
                style: RaverTypography.body(
                  size: 14,
                  color: theme.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _entityTypeLabel(String type) => switch (type) {
        'event' => lt('活动', 'Event', 'イベント'),
        'dj' => 'DJ',
        'brand' => lt('厂牌', 'Brand', 'ブランド'),
        _ => type,
      };

  static Color _changeTypeColor(String type) => switch (type) {
        'cancelled' => const Color(0xFFD93636),
        'lineup_update' => const Color(0xFF6B42DB),
        'schedule_update' => const Color(0xFFF88A35),
        'venue_update' => const Color(0xFF4DABF7),
        _ => const Color(0xFF70C754),
      };
}
