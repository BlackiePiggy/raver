import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

/// Permission guide screen.
class PermissionGuideScreen extends StatelessWidget {
  const PermissionGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('权限引导', 'Permission Guide', '権限ガイド')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PermissionItem(
            icon: Icons.camera_alt_outlined,
            title: lt('相机', 'Camera', 'カメラ'),
            description: lt(
              '用于拍摄头像、签到照片',
              'Used for taking avatars and check-in photos',
              'アバターやチェックイン写真の撮影に使用',
            ),
            status: lt('未授权', 'Not granted', '未許可'),
            theme: theme,
          ),
          const SizedBox(height: 8),
          _PermissionItem(
            icon: Icons.photo_library_outlined,
            title: lt('相册', 'Photo Library', 'フォトライブラリ'),
            description: lt(
              '用于选择头像和上传照片',
              'Used for selecting avatars and uploading photos',
              'アバターの選択と写真のアップロードに使用',
            ),
            status: lt('未授权', 'Not granted', '未許可'),
            theme: theme,
          ),
          const SizedBox(height: 8),
          _PermissionItem(
            icon: Icons.location_on_outlined,
            title: lt('位置', 'Location', '位置情報'),
            description: lt(
              '用于签到和附近活动推荐',
              'Used for check-ins and nearby event recommendations',
              'チェックインと近くのイベントの推奨に使用',
            ),
            status: lt('未授权', 'Not granted', '未許可'),
            theme: theme,
          ),
          const SizedBox(height: 8),
          _PermissionItem(
            icon: Icons.notifications_outlined,
            title: lt('通知', 'Notifications', '通知'),
            description: lt(
              '用于接收活动提醒和消息通知',
              'Used for event reminders and message notifications',
              'イベントリマインダーとメッセージ通知に使用',
            ),
            status: lt('未授权', 'Not granted', '未許可'),
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String description;
  final String status;
  final RaverThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: RaverTypography.label(
                    size: 15,
                    color: theme.primaryText,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: RaverTypography.caption(color: theme.secondaryText),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.cardBorder,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: RaverTypography.caption(
                color: theme.secondaryText,
                weight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
