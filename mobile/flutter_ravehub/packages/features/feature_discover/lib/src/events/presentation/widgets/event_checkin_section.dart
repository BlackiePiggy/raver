import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';

import '../../data/event_discussion_models.dart';
import '../../data/events_repository.dart';

/// Check-in section: check-in button, checked-in user avatars, and status.
class EventCheckInSection extends StatefulWidget {
  const EventCheckInSection({
    super.key,
    required this.eventId,
    required this.repository,
  });

  final String eventId;
  final EventsRepository repository;

  @override
  State<EventCheckInSection> createState() => _EventCheckInSectionState();
}

class _EventCheckInSectionState extends State<EventCheckInSection> {
  bool _isLoading = true;
  bool _isCheckingIn = false;
  String? _myCheckinAt;
  List<EventCheckinUser> _users = [];
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCheckins();
  }

  Future<void> _loadCheckins() async {
    try {
      final result = await widget.repository.fetchCheckins(
        eventId: widget.eventId,
      );
      if (mounted) {
        setState(() {
          _users = result.users;
          _totalCount = result.totalCount;
          _myCheckinAt = result.myCheckinAt;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _doCheckin() async {
    if (_isCheckingIn || _myCheckinAt != null) return;
    setState(() => _isCheckingIn = true);

    try {
      final result = await widget.repository.checkin(eventId: widget.eventId);
      if (mounted) {
        setState(() {
          _myCheckinAt = result.checkedInAt;
          _totalCount++;
          _isCheckingIn = false;
        });
        ToastBanner.show(
          context,
          message: lt('签到成功', 'Checked in!', 'チェックイン完了'),
          type: ToastType.success,
        );
        _loadCheckins();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingIn = false);
        ToastBanner.show(
          context,
          message: lt('签到失败', 'Check-in failed', 'チェックインに失敗しました'),
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;
    final hasCheckedIn = _myCheckinAt != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lt('签到', 'Check-in', 'チェックイン'),
            style: RaverTypography.title(size: 16, color: theme.primaryText),
          ),
          const SizedBox(height: 12),
          // Check-in button
          GestureDetector(
            onTap: hasCheckedIn ? null : _doCheckin,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: hasCheckedIn
                    ? theme.accent.withValues(alpha: 0.12)
                    : theme.accent,
                borderRadius: BorderRadius.circular(12),
                border: hasCheckedIn
                    ? Border.all(color: theme.accent.withValues(alpha: 0.3))
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isCheckingIn)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: hasCheckedIn ? theme.accent : Colors.white,
                      ),
                    )
                  else
                    Icon(
                      hasCheckedIn
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      size: 20,
                      color: hasCheckedIn ? theme.accent : Colors.white,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    hasCheckedIn
                        ? lt('已签到', 'Checked In', 'チェックイン済み')
                        : lt('签到', 'Check In', 'チェックイン'),
                    style: RaverTypography.label(
                      size: 15,
                      color: hasCheckedIn ? theme.accent : Colors.white,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (hasCheckedIn) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatCheckinTime(_myCheckinAt!),
                      style: RaverTypography.caption(
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Checked-in user avatars
          if (_isLoading)
            const Center(child: CircularProgressIndicator.adaptive())
          else if (_users.isNotEmpty) ...[
            Row(
              children: [
                // Avatar row (max 10)
                ..._users.take(10).map((user) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ClipOval(
                      child: user.avatarUrl.isNotEmpty
                          ? RemoteCoverImage(
                              url: user.avatarUrl,
                              width: 30,
                              height: 30,
                            )
                          : Container(
                              width: 30,
                              height: 30,
                              color: theme.cardBorder,
                              child: Icon(
                                Icons.person,
                                color: theme.secondaryText,
                                size: 16,
                              ),
                            ),
                    ),
                  );
                }),
                const SizedBox(width: 6),
                Text(
                  '$_totalCount ${lt('人已签到', 'checked in', '人がチェックイン')}',
                  style: RaverTypography.caption(color: theme.secondaryText),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatCheckinTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
