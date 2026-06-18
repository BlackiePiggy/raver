import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

/// Share section: a button that invokes the platform share sheet.
class EventShareSection extends StatelessWidget {
  const EventShareSection({
    super.key,
    required this.eventId,
    required this.eventName,
    this.onShare,
  });

  final String eventId;
  final String eventName;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onShare ??
            () {
              final url = 'https://ravehub.top/events/$eventId';
              ShareService.shareUrl(
                url,
                subject: eventName,
              );
            },
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.share_outlined, size: 18, color: theme.accent),
              const SizedBox(width: 8),
              Text(
                lt('分享活动', 'Share Event', 'イベントをシェア'),
                style: RaverTypography.label(
                  size: 14,
                  color: theme.accent,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
