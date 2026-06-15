import 'package:flutter/material.dart';
import 'package:raver_design_system/raver_design_system.dart';
import 'package:raver_i18n/raver_i18n.dart';
import 'package:raver_models/raver_models.dart';

/// Displays the timetable grouped by stage with time slots and DJ assignments.
///
/// Reads the already-loaded timetable data from the parent screen and presents
/// a stage-switchable view.
class EventScheduleSection extends StatefulWidget {
  const EventScheduleSection({
    super.key,
    required this.timetable,
  });

  final List<WebEventLineupSlot> timetable;

  @override
  State<EventScheduleSection> createState() => _EventScheduleSectionState();
}

class _EventScheduleSectionState extends State<EventScheduleSection> {
  String? _selectedStage;

  Map<String, List<WebEventLineupSlot>> get _grouped {
    final map = <String, List<WebEventLineupSlot>>{};
    for (final slot in widget.timetable) {
      (map[slot.stageName] ??= []).add(slot);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.raver;

    if (widget.timetable.isEmpty) {
      return EmptyStateView(
        icon: Icons.schedule,
        title: lt('暂无时间表', 'No Timetable', 'タイムテーブルなし'),
      );
    }

    final grouped = _grouped;
    final stages = grouped.keys.toList();

    if (_selectedStage == null || !stages.contains(_selectedStage)) {
      _selectedStage = stages.first;
    }

    final slots = grouped[_selectedStage!] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            lt('时间表', 'Timetable', 'タイムテーブル'),
            style: RaverTypography.title(size: 16, color: theme.primaryText),
          ),
        ),
        const SizedBox(height: 12),
        // Stage selector
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: stages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final stage = stages[index];
              final isSelected = stage == _selectedStage;
              return GestureDetector(
                onTap: () => setState(() => _selectedStage = stage),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.accent
                        : theme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    stage,
                    style: RaverTypography.label(
                      size: 13,
                      color: isSelected ? Colors.white : theme.accent,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Time slots
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: slots.map((slot) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatTime(slot.startTime)} - ${_formatTime(slot.endTime)}',
                            style: RaverTypography.caption(
                              color: theme.secondaryText,
                              weight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            slot.stageName,
                            style: RaverTypography.caption(
                              color: theme.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          slot.artistName,
                          style: RaverTypography.body(
                            size: 14,
                            color: theme.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
