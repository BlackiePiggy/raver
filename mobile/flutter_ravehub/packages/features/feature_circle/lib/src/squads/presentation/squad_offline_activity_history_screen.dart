import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

import '../view_models/squad_view_model.dart';
import '../../_shared/circle_service_locator.dart';

/// Screen showing the full history of offline activities for a squad.
class SquadOfflineActivityHistoryScreen extends StatefulWidget {
  const SquadOfflineActivityHistoryScreen({
    super.key,
    required this.squadId,
  });

  final String squadId;

  @override
  State<SquadOfflineActivityHistoryScreen> createState() =>
      _SquadOfflineActivityHistoryScreenState();
}

class _SquadOfflineActivityHistoryScreenState
    extends State<SquadOfflineActivityHistoryScreen> {
  late final SquadProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = SquadProfileViewModel(
      squadId: widget.squadId,
      repository: CircleServiceLocator.squadRepository,
    );
    _viewModel.addListener(_rebuild);
    _viewModel.load();
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
        backgroundColor: theme.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          lt('活动历史', 'Activity History', '活動履歴'),
          style: RaverTypography.title(size: 17, color: theme.primaryText),
        ),
        elevation: 0,
      ),
      body: _viewModel.activities.isEmpty
          ? EmptyStateView(
              icon: Icons.history,
              title: lt(
                '暂无活动历史',
                'No activity history',
                '活動履歴はありません',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _viewModel.activities.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final activity = _viewModel.activities[index];
                final isOngoing = activity.status == 'ongoing';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOngoing
                              ? Colors.green
                              : theme.secondaryText,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.eventName,
                              style: RaverTypography.label(
                                size: 14,
                                color: theme.primaryText,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDateRange(
                                activity.startedAt,
                                activity.endedAt,
                              ),
                              style: RaverTypography.caption(
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (activity.participants != null)
                        Text(
                          '${activity.participants!.length} ${lt("人", "ppl", "人")}',
                          style: RaverTypography.caption(
                            color: theme.secondaryText,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  static String _formatDateRange(String start, String end) {
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      return '${s.month}/${s.day} - ${e.month}/${e.day}';
    } catch (_) {
      return '$start - $end';
    }
  }
}
