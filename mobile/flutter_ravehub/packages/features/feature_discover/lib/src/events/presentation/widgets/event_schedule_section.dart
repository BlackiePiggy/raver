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
    required this.event,
    required this.timetable,
  });

  final WebEvent event;
  final List<WebEventLineupSlot> timetable;

  @override
  State<EventScheduleSection> createState() => _EventScheduleSectionState();
}

class _EventScheduleSectionState extends State<EventScheduleSection> {
  static const int _dayRolloverHour = 6;

  String? _selectedDayId;
  String? _selectedStage;

  List<_ScheduleDay> get _days {
    final structuredDays = <_ScheduleDay>[];
    final weeks = widget.event.weeks ?? const <WebEventWeek>[];
    for (var weekIndex = 0; weekIndex < weeks.length; weekIndex += 1) {
      final week = weeks[weekIndex];
      for (var dayIndex = 0; dayIndex < week.days.length; dayIndex += 1) {
        final day = week.days[dayIndex];
        if (day.date.trim().isEmpty) continue;
        final prefix = weeks.length > 1
            ? '${lt('第 ${weekIndex + 1} 周', 'Week ${weekIndex + 1}', 'Week ${weekIndex + 1}')} · '
            : '';
        structuredDays.add(
          _ScheduleDay(
            id: day.id.isNotEmpty ? day.id : day.date,
            date: _dateOnly(day.date),
            label:
                '$prefix${day.label.isNotEmpty ? day.label : _dayLabel(dayIndex + 1, day.date)}',
          ),
        );
      }
    }
    if (structuredDays.isNotEmpty) return structuredDays;

    final start = _parseDateOnly(widget.event.startDate);
    final end = _parseDateOnly(widget.event.endDate);
    if (start != null && end != null && !end.isBefore(start)) {
      final totalDays = end.difference(start).inDays + 1;
      if (totalDays > 1 && totalDays <= 31) {
        return List<_ScheduleDay>.generate(totalDays, (index) {
          final date = start.add(Duration(days: index));
          final value = _formatDateOnly(date);
          return _ScheduleDay(
            id: value,
            date: value,
            label: _dayLabel(index + 1, value),
          );
        });
      }
    }

    final uniqueDates = <String>{};
    for (final slot in widget.timetable) {
      final date = _logicalDateForSlot(slot);
      if (date != null) uniqueDates.add(date);
    }
    final sorted = uniqueDates.toList()..sort();
    return sorted
        .asMap()
        .entries
        .map(
          (entry) => _ScheduleDay(
            id: entry.value,
            date: entry.value,
            label: _dayLabel(entry.key + 1, entry.value),
          ),
        )
        .toList();
  }

  Map<String, List<WebEventLineupSlot>> _groupedByStage(
    Iterable<WebEventLineupSlot> slots,
  ) {
    final map = <String, List<WebEventLineupSlot>>{};
    for (final slot in slots) {
      final stageName = slot.stageName.trim().isNotEmpty
          ? slot.stageName.trim()
          : lt('未知舞台', 'Unknown Stage', '不明なステージ');
      (map[stageName] ??= []).add(slot);
    }
    for (final stageSlots in map.values) {
      stageSlots.sort((a, b) => a.startTime.compareTo(b.startTime));
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

    final days = _days;
    final selectedDay = _selectedDay(days);
    final daySlots = selectedDay == null
        ? widget.timetable
        : widget.timetable
            .where((slot) => _logicalDateForSlot(slot) == selectedDay.date)
            .toList();
    final grouped = _groupedByStage(daySlots);
    final stages = grouped.keys.toList();

    if (_selectedDayId == null && days.isNotEmpty) {
      _selectedDayId = days.first.id;
    }
    if (_selectedStage == null || !stages.contains(_selectedStage)) {
      _selectedStage = stages.isEmpty ? null : stages.first;
    }

    final slots =
        _selectedStage == null ? const [] : grouped[_selectedStage!] ?? [];

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
        if (days.length > 1) ...[
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = days[index];
                final isSelected = day.id == _selectedDayId;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDayId = day.id;
                      _selectedStage = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? theme.accent : theme.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? theme.accent : theme.cardBorder,
                      ),
                    ),
                    child: Text(
                      day.label,
                      style: RaverTypography.label(
                        size: 13,
                        color: isSelected ? Colors.white : theme.primaryText,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
        // Stage selector
        if (stages.isNotEmpty) ...[
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
        ],
        // Time slots
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: slots.isEmpty
              ? EmptyStateView(
                  icon: Icons.schedule,
                  title: lt('当天暂无排程', 'No Schedule This Day', 'この日のスケジュールなし'),
                )
              : Column(
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
                                  _formatSlotTimeRange(slot, selectedDay?.date),
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

  _ScheduleDay? _selectedDay(List<_ScheduleDay> days) {
    if (days.isEmpty) return null;
    if (_selectedDayId == null ||
        !days.any((day) => day.id == _selectedDayId)) {
      _selectedDayId = days.first.id;
    }
    return days.firstWhere((day) => day.id == _selectedDayId);
  }

  static String? _logicalDateForSlot(WebEventLineupSlot slot) {
    final date = _parseDateOnly(slot.startTime);
    final hour = _hourFromIso(slot.startTime);
    if (date == null) return null;
    final logical = hour != null && hour < _dayRolloverHour
        ? date.subtract(const Duration(days: 1))
        : date;
    return _formatDateOnly(logical);
  }

  static String _formatSlotTimeRange(WebEventLineupSlot slot, String? dayDate) {
    final start = _hourMinute(slot.startTime);
    final end = _hourMinute(slot.endTime);
    final startDate = _dateOnly(slot.startTime);
    final endDate = _dateOnly(slot.endTime);
    final logicalDay = dayDate ?? _logicalDateForSlot(slot) ?? startDate;
    final startPrefix = _dayOffsetPrefix(startDate, logicalDay);
    final endPrefix = _dayOffsetPrefix(endDate, logicalDay);
    return '$startPrefix$start - $endPrefix$end';
  }

  static String _dayOffsetPrefix(String date, String logicalDay) {
    if (date.isEmpty || logicalDay.isEmpty || date == logicalDay) return '';
    final actual = _parseDateOnly(date);
    final logical = _parseDateOnly(logicalDay);
    if (actual == null || logical == null) return '';
    return actual.isAfter(logical) ? lt('次日 ', 'Next day ', '翌日') : '';
  }

  static String _hourMinute(String iso) {
    final match = RegExp(r'T(\d{2}):(\d{2})').firstMatch(iso);
    if (match != null) return '${match.group(1)}:${match.group(2)}';
    return iso;
  }

  static int? _hourFromIso(String iso) {
    final match = RegExp(r'T(\d{2})').firstMatch(iso);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static String _dateOnly(String value) {
    final match = RegExp(r'^(\d{4}-\d{2}-\d{2})').firstMatch(value);
    return match?.group(1) ?? value;
  }

  static DateTime? _parseDateOnly(String value) {
    final date = _dateOnly(value);
    if (date.length < 10) return null;
    return DateTime.tryParse(date);
  }

  static String _formatDateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _dayLabel(int index, String date) {
    final compactDate = date.length >= 10 ? date.substring(5, 10) : date;
    return lt('第 $index 天 · $compactDate', 'Day $index · $compactDate',
        'Day $index · $compactDate');
  }
}

class _ScheduleDay {
  const _ScheduleDay({
    required this.id,
    required this.date,
    required this.label,
  });

  final String id;
  final String date;
  final String label;
}
