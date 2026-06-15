import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../_shared/profile_service_locator.dart';
import 'view_models/settings_view_model.dart';

/// Device management screen.
class DeviceManageScreen extends StatefulWidget {
  const DeviceManageScreen({super.key});

  @override
  State<DeviceManageScreen> createState() => _DeviceManageScreenState();
}

class _DeviceManageScreenState extends State<DeviceManageScreen> {
  late final SettingsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = SettingsViewModel(
      repository: ProfileServiceLocator.profileRepository,
    );
    _viewModel.addListener(_rebuild);
    _viewModel.loadDevices();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_rebuild);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('设备管理', 'Device Management', 'デバイス管理')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _viewModel.isLoadingDevices
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _viewModel.devices.isEmpty
              ? Center(
                  child: EmptyStateView(
                    icon: Icons.devices_outlined,
                    title: lt('暂无设备', 'No Devices', 'デバイスなし'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _viewModel.devices.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == _viewModel.devices.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: OutlinedButton(
                          onPressed: _logoutOtherDevices,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            lt('登出其他设备', 'Log Out Other Devices',
                                '他のデバイスからログアウト'),
                            style: RaverTypography.label(
                              size: 14,
                              color: Colors.redAccent,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }

                    final device = _viewModel.devices[index];
                    return _buildDeviceCard(device, theme);
                  },
                ),
    );
  }

  Widget _buildDeviceCard(AuthSessionItem device, RaverThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.smartphone,
            size: 28,
            color: device.isCurrent ? theme.accent : theme.secondaryText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.deviceInfo,
                        style: RaverTypography.label(
                          size: 15,
                          color: theme.primaryText,
                          weight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (device.isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          lt('当前', 'Current', '現在'),
                          style: RaverTypography.caption(
                            color: theme.accent,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${lt('最近活跃', 'Last active', '最終アクティブ')}: ${device.lastActiveAt}',
                  style: RaverTypography.caption(color: theme.secondaryText),
                ),
              ],
            ),
          ),
          if (!device.isCurrent)
            IconButton(
              icon: Icon(Icons.close, color: theme.secondaryText, size: 18),
              onPressed: () => _viewModel.removeDevice(device.id),
            ),
        ],
      ),
    );
  }

  void _logoutOtherDevices() {
    final theme = context.raver;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.card,
        title: Text(
          lt('确认登出', 'Confirm Logout', 'ログアウトの確認'),
          style: RaverTypography.title(color: theme.primaryText),
        ),
        content: Text(
          lt('将登出除当前设备外的所有设备',
              'All other devices will be logged out',
              '現在のデバイス以外のすべてのデバイスからログアウトされます'),
          style: RaverTypography.body(size: 14, color: theme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lt('取消', 'Cancel', 'キャンセル')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              for (final d in _viewModel.devices) {
                if (!d.isCurrent) {
                  _viewModel.removeDevice(d.id);
                }
              }
            },
            child: Text(
              lt('确认', 'Confirm', '確認'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
