import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

/// Route tool screen for navigation assistance.
class RouteToolScreen extends StatefulWidget {
  const RouteToolScreen({super.key});

  @override
  State<RouteToolScreen> createState() => _RouteToolScreenState();
}

class _RouteToolScreenState extends State<RouteToolScreen> {
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  bool _useCurrentLocation = true;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _startNavigation() async {
    final destination = _endController.text.trim();
    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lt('请输入终点', 'Enter a destination', '目的地を入力してください')),
        ),
      );
      return;
    }

    final origin = _useCurrentLocation ? null : _startController.text.trim();
    if (!_useCurrentLocation && (origin == null || origin.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lt('请输入起点', 'Enter a start location', '出発地を入力してください')),
        ),
      );
      return;
    }

    try {
      await MapLauncher.openRoute(
        originQuery: origin,
        destinationQuery: destination,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lt(
              '无法打开地图应用，请稍后重试',
              'Unable to open Maps. Please try again.',
              'マップを開けませんでした。もう一度お試しください。',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      appBar: AppBar(
        title: Text(lt('路线工具', 'Route Tool', 'ルートツール')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Start point
            Text(
              lt('起点', 'Start', '出発地'),
              style: RaverTypography.label(
                size: 14,
                color: theme.secondaryText,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _useCurrentLocation,
                  onChanged: (value) =>
                      setState(() => _useCurrentLocation = value ?? true),
                  activeColor: theme.accent,
                ),
                Text(
                  lt('使用当前位置', 'Use current location', '現在地を使用'),
                  style: RaverTypography.body(
                    size: 14,
                    color: theme.primaryText,
                  ),
                ),
              ],
            ),
            if (!_useCurrentLocation)
              TextField(
                controller: _startController,
                decoration: InputDecoration(
                  hintText: lt('输入起点', 'Enter start location', '出発地を入力'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.cardBorder),
                  ),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
            const SizedBox(height: 20),

            // End point
            Text(
              lt('终点', 'Destination', '目的地'),
              style: RaverTypography.label(
                size: 14,
                color: theme.secondaryText,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _endController,
              decoration: InputDecoration(
                hintText: lt(
                  '搜索场馆或活动',
                  'Search venue or event',
                  '会場またはイベントを検索',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.cardBorder),
                ),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 32),

            // Start navigation button
            PrimaryButton(
              label: lt('开始导航', 'Start Navigation', 'ナビ開始'),
              icon: Icons.navigation_outlined,
              onPressed: _startNavigation,
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}
