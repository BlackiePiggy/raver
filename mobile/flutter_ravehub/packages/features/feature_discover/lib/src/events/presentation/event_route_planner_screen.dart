import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_platform/raver_platform.dart';

class EventRoutePlannerScreen extends StatefulWidget {
  const EventRoutePlannerScreen({
    super.key,
    required this.eventId,
    required this.venueName,
    required this.latitude,
    required this.longitude,
  });

  final String eventId;
  final String venueName;
  final double latitude;
  final double longitude;

  @override
  State<EventRoutePlannerScreen> createState() =>
      _EventRoutePlannerScreenState();
}

class _EventRoutePlannerScreenState extends State<EventRoutePlannerScreen> {
  double? _currentLat;
  double? _currentLng;
  bool _isLoadingLocation = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) return;
      _currentLat = position.latitude;
      _currentLng = position.longitude;
    } catch (e) {
      _locationError = e.toString();
    }
    if (mounted) {
      setState(() => _isLoadingLocation = false);
    }
  }

  double? _calculateDistance() {
    if (_currentLat == null || _currentLng == null) return null;
    return _haversineDistance(
      _currentLat!,
      _currentLng!,
      widget.latitude,
      widget.longitude,
    );
  }

  /// Haversine formula — returns distance in kilometres.
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180);

  void _navigate() {
    MapLauncher.launchNavigation(
      latitude: widget.latitude,
      longitude: widget.longitude,
      label: widget.venueName,
    );
  }

  void _shareRoute() {
    ShareService.share(
      text:
          'Navigate to ${widget.venueName}: https://maps.google.com/?q=${widget.latitude},${widget.longitude}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    return Scaffold(
      body: RaverNavigationChrome(
        title: lt('路线规划', 'Route Planner', 'ルートプランナー'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current location
              Text(
                lt('当前位置', 'Current Location', '現在地'),
                style:
                    RaverTypography.title(size: 16, color: theme.primaryText),
              ),
              const SizedBox(height: 8),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCurrentLocation(theme),
                ),
              ),

              const SizedBox(height: 24),

              // Destination
              Text(
                lt('目的地', 'Destination', '目的地'),
                style:
                    RaverTypography.title(size: 16, color: theme.primaryText),
              ),
              const SizedBox(height: 8),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: theme.accent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.venueName,
                              style: RaverTypography.label(
                                size: 15,
                                color: theme.primaryText,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                        style: RaverTypography.caption(
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Distance
              if (!_isLoadingLocation && _currentLat != null) ...[
                Text(
                  lt('预计距离', 'Estimated Distance', '推定距離'),
                  style: RaverTypography.title(
                    size: 16,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.straighten, color: theme.accent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _formatDistance(_calculateDistance()),
                          style: RaverTypography.headline(
                            color: theme.primaryText,
                          ).copyWith(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Action buttons
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: lt('导航', 'Navigate', 'ナビゲーション'),
                  onPressed: _navigate,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: lt('分享路线', 'Share Route', 'ルートを共有'),
                  variant: PrimaryButtonVariant.outline,
                  onPressed: _shareRoute,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentLocation(RaverThemeData theme) {
    if (_isLoadingLocation) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            lt('获取位置中...', 'Getting location...', '位置を取得中...'),
            style: RaverTypography.body(size: 14, color: theme.secondaryText),
          ),
        ],
      );
    }

    if (_locationError != null) {
      return Row(
        children: [
          Icon(Icons.error_outline, color: theme.secondaryText, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lt('无法获取当前位置', 'Unable to get location', '現在地を取得できません'),
              style:
                  RaverTypography.body(size: 14, color: theme.secondaryText),
            ),
          ),
          GestureDetector(
            onTap: _fetchCurrentLocation,
            child: Text(
              lt('重试', 'Retry', '再試行'),
              style: RaverTypography.label(
                size: 13,
                color: theme.accent,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.my_location, color: theme.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              lt('我的位置', 'My Location', '私の位置'),
              style: RaverTypography.label(
                size: 15,
                color: theme.primaryText,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${_currentLat!.toStringAsFixed(6)}, ${_currentLng!.toStringAsFixed(6)}',
          style: RaverTypography.caption(color: theme.secondaryText),
        ),
      ],
    );
  }

  static String _formatDistance(double? km) {
    if (km == null) return '-';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}
