import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

class FollowedUpdateTile extends StatelessWidget {
  const FollowedUpdateTile({
    super.key,
    required this.entityName,
    required this.updateType,
    required this.updateTitle,
    required this.summary,
    required this.occurredAt,
    required this.isRead,
    required this.placeholderIcon,
    this.imageUrl = '',
    this.avatar = false,
    this.onTap,
  });

  final String entityName;
  final String updateType;
  final String updateTitle;
  final String summary;
  final String occurredAt;
  final bool isRead;
  final IconData placeholderIcon;
  final String imageUrl;
  final bool avatar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead
                ? theme.cardBorder
                : theme.accent.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            _Thumb(
              imageUrl: imageUrl,
              icon: placeholderIcon,
              avatar: avatar,
              theme: theme,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _UpdateTypeTag(type: updateType),
                      if (!isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: theme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entityName,
                          style: RaverTypography.caption(
                            color: theme.secondaryText,
                            weight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    updateTitle.isEmpty ? entityName : updateTitle,
                    style: RaverTypography.label(
                      size: 14,
                      color: theme.primaryText,
                      weight: isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      style: RaverTypography.caption(
                        color: theme.secondaryText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    _formatRelativeTime(occurredAt),
                    style: RaverTypography.caption(color: theme.secondaryText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 20, color: theme.secondaryText),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.imageUrl,
    required this.icon,
    required this.avatar,
    required this.theme,
  });

  final String imageUrl;
  final IconData icon;
  final bool avatar;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    final child = imageUrl.isNotEmpty
        ? RemoteCoverImage(url: imageUrl, width: 56, height: 56)
        : Container(
            width: 56,
            height: 56,
            color: theme.cardBorder,
            child: Icon(icon, color: theme.secondaryText),
          );
    if (avatar) return ClipOval(child: child);
    return ClipRRect(borderRadius: BorderRadius.circular(8), child: child);
  }
}

class _UpdateTypeTag extends StatelessWidget {
  const _UpdateTypeTag({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _labelForType(type),
        style: RaverTypography.caption(color: color, weight: FontWeight.w600),
      ),
    );
  }

  static String _labelForType(String type) {
    switch (type.toLowerCase()) {
      case 'event':
        return lt('活动', 'Event', 'イベント');
      case 'news':
        return lt('资讯', 'News', 'ニュース');
      default:
        return type.isEmpty ? lt('更新', 'Update', '更新') : type;
    }
  }

  static Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'event':
        return const Color(0xFF4DABF7);
      case 'news':
        return const Color(0xFF70C754);
      default:
        return const Color(0xFFC278F2);
    }
  }
}

String _formatRelativeTime(String iso) {
  try {
    final dt = DateTime.parse(iso);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return lt('刚刚', 'just now', 'たった今');
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  } catch (_) {
    return iso;
  }
}
