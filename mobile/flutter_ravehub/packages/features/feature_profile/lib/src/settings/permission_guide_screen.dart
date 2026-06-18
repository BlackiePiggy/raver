import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

/// Permission guide screen.
class PermissionGuideScreen extends StatefulWidget {
  const PermissionGuideScreen({super.key});

  @override
  State<PermissionGuideScreen> createState() => _PermissionGuideScreenState();
}

class _PermissionGuideScreenState extends State<PermissionGuideScreen>
    with WidgetsBindingObserver {
  final _permissionService = PermissionService();
  final Map<_PermissionKind, RaverPermissionStatus> _statuses = {};
  _PermissionKind? _busyKind;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
  }

  Future<void> _refreshStatuses() async {
    final statuses = await Future.wait([
      _permissionService.cameraStatus(),
      _permissionService.photosStatus(),
      _permissionService.locationStatus(),
      _permissionService.notificationStatus(),
    ]);
    if (!mounted) return;
    setState(() {
      _statuses
        ..clear()
        ..addAll({
          _PermissionKind.camera: statuses[0],
          _PermissionKind.photos: statuses[1],
          _PermissionKind.location: statuses[2],
          _PermissionKind.notifications: statuses[3],
        });
    });
  }

  Future<void> _handlePermissionTap(_PermissionKind kind) async {
    final current = _statuses[kind];
    if (current == RaverPermissionStatus.granted ||
        current == RaverPermissionStatus.limited ||
        current == RaverPermissionStatus.provisional) {
      return;
    }

    setState(() => _busyKind = kind);
    try {
      if (current == RaverPermissionStatus.permanentlyDenied ||
          current == RaverPermissionStatus.restricted) {
        await _permissionService.openSettings();
      } else {
        final updated = await _request(kind);
        if (!mounted) return;
        setState(() => _statuses[kind] = updated);
      }
    } finally {
      if (mounted) setState(() => _busyKind = null);
    }
  }

  Future<RaverPermissionStatus> _request(_PermissionKind kind) {
    return switch (kind) {
      _PermissionKind.camera => _permissionService.requestCameraStatus(),
      _PermissionKind.photos => _permissionService.requestPhotosStatus(),
      _PermissionKind.location => _permissionService.requestLocationStatus(),
      _PermissionKind.notifications =>
        _permissionService.requestNotificationStatus(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final items = [
      _PermissionSpec(
        kind: _PermissionKind.camera,
        icon: Icons.camera_alt_outlined,
        title: lt('相机', 'Camera', 'カメラ'),
        description: lt(
          '用于扫码、拍摄头像、签到照片',
          'Used for scanning QR codes, avatars, and check-in photos',
          'QRコードのスキャン、アバター、チェックイン写真に使用',
        ),
      ),
      _PermissionSpec(
        kind: _PermissionKind.photos,
        icon: Icons.photo_library_outlined,
        title: lt('相册', 'Photo Library', 'フォトライブラリ'),
        description: lt(
          '用于选择头像、上传照片、保存二维码和分享卡片',
          'Used for avatars, uploads, and saving QR/share cards',
          'アバター選択、アップロード、QR/共有カードの保存に使用',
        ),
      ),
      _PermissionSpec(
        kind: _PermissionKind.location,
        icon: Icons.location_on_outlined,
        title: lt('位置', 'Location', '位置情報'),
        description: lt(
          '用于签到、路线工具和附近活动推荐',
          'Used for check-ins, route tools, and nearby recommendations',
          'チェックイン、ルートツール、近くのイベント推薦に使用',
        ),
      ),
      _PermissionSpec(
        kind: _PermissionKind.notifications,
        icon: Icons.notifications_outlined,
        title: lt('通知', 'Notifications', '通知'),
        description: lt(
          '用于接收活动提醒、审核结果和消息通知',
          'Used for event reminders, review updates, and messages',
          'イベント通知、審査結果、メッセージ通知に使用',
        ),
      ),
    ];

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
          Text(
            lt(
              'RaveHub 会在你使用具体功能时请求权限，也可以在这里提前开启。',
              'RaveHub asks for permissions when a feature needs them. You can also enable them here first.',
              'RaveHubは機能が必要な時に権限を求めます。ここで事前に有効にすることもできます。',
            ),
            style: RaverTypography.body(size: 14, color: theme.secondaryText),
          ),
          const SizedBox(height: 16),
          for (final item in items) ...[
            _PermissionItem(
              icon: item.icon,
              title: item.title,
              description: item.description,
              status: _statuses[item.kind],
              isBusy: _busyKind == item.kind,
              theme: theme,
              onTap: () => _handlePermissionTap(item.kind),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

enum _PermissionKind { camera, photos, location, notifications }

class _PermissionSpec {
  const _PermissionSpec({
    required this.kind,
    required this.icon,
    required this.title,
    required this.description,
  });

  final _PermissionKind kind;
  final IconData icon;
  final String title;
  final String description;
}

class _PermissionItem extends StatelessWidget {
  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.isBusy,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final RaverPermissionStatus? status;
  final bool isBusy;
  final RaverThemeData theme;
  final VoidCallback onTap;

  String _statusLabel() {
    return switch (status) {
      null => lt('检查中', 'Checking', '確認中'),
      RaverPermissionStatus.granted => lt('已开启', 'Enabled', '有効'),
      RaverPermissionStatus.limited => lt('部分开启', 'Limited', '一部有効'),
      RaverPermissionStatus.provisional => lt('临时开启', 'Provisional', '暫定有効'),
      RaverPermissionStatus.permanentlyDenied =>
        lt('去设置', 'Open Settings', '設定へ'),
      RaverPermissionStatus.restricted => lt('受限', 'Restricted', '制限中'),
      RaverPermissionStatus.denied => lt('开启', 'Enable', '有効にする'),
    };
  }

  Color _statusColor() {
    return switch (status) {
      RaverPermissionStatus.granted ||
      RaverPermissionStatus.limited ||
      RaverPermissionStatus.provisional =>
        const Color(0xFF1B9E5C),
      RaverPermissionStatus.permanentlyDenied ||
      RaverPermissionStatus.restricted =>
        const Color(0xFFD98B28),
      _ => theme.accent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isBusy ? null : onTap,
      child: Container(
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
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              constraints: const BoxConstraints(minWidth: 68),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: statusColor.withValues(alpha: 0.32)),
              ),
              child: isBusy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    )
                  : Text(
                      _statusLabel(),
                      textAlign: TextAlign.center,
                      style: RaverTypography.caption(
                        color: statusColor,
                        weight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
