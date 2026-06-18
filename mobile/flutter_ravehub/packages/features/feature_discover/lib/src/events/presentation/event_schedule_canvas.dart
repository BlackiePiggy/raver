import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A CustomPainter-based timetable visualizer for event schedules.
///
/// Displays schedule entries as colored rounded rectangles on a time/stage grid.
/// X-axis represents time, Y-axis represents stages.
class EventScheduleCanvas extends StatelessWidget {
  const EventScheduleCanvas({
    super.key,
    required this.schedule,
    this.readOnly = false,
    this.onTap,
  });

  /// List of schedule entries. Each map should contain:
  /// - `stageName` (String)
  /// - `djName` (String)
  /// - `startTime` (String, ISO 8601)
  /// - `endTime` (String, ISO 8601)
  final List<Map<String, dynamic>> schedule;

  /// Whether taps are disabled.
  final bool readOnly;

  /// Callback invoked when a schedule entry is tapped.
  final void Function(Map<String, dynamic>)? onTap;

  @override
  Widget build(BuildContext context) {
    if (schedule.isEmpty) {
      return const SizedBox.shrink();
    }

    final parsed = _parseSchedule(schedule);
    if (parsed.stages.isEmpty || parsed.minTime == null) {
      return const SizedBox.shrink();
    }

    final totalHours =
        parsed.maxTime!.difference(parsed.minTime!).inMinutes / 60;
    const pixelsPerHour = 60.0;
    const stageHeight = 48.0;
    const leftPad = 80.0; // space for stage labels
    const topPad = 24.0; // space for hour labels

    final canvasWidth = leftPad + totalHours * pixelsPerHour + 16;
    final canvasHeight = topPad + parsed.stages.length * stageHeight + 16;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: GestureDetector(
        onTapDown: readOnly
            ? null
            : (details) {
                final hit = _hitTest(
                  details.localPosition,
                  parsed,
                  leftPad: leftPad,
                  topPad: topPad,
                  pixelsPerHour: pixelsPerHour,
                  stageHeight: stageHeight,
                );
                if (hit != null && onTap != null) {
                  onTap!(hit);
                }
              },
        child: CustomPaint(
          size: Size(canvasWidth, canvasHeight),
          painter: EventScheduleCanvasPainter(
            parsed: parsed,
            leftPad: leftPad,
            topPad: topPad,
            pixelsPerHour: pixelsPerHour,
            stageHeight: stageHeight,
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _hitTest(
    Offset position,
    _ParsedSchedule parsed, {
    required double leftPad,
    required double topPad,
    required double pixelsPerHour,
    required double stageHeight,
  }) {
    for (final entry in parsed.entries) {
      final stageIndex = parsed.stages.indexOf(entry.stageName);
      if (stageIndex < 0) continue;

      final startOffset =
          entry.startTime.difference(parsed.minTime!).inMinutes / 60;
      final endOffset =
          entry.endTime.difference(parsed.minTime!).inMinutes / 60;

      final x = leftPad + startOffset * pixelsPerHour;
      final y = topPad + stageIndex * stageHeight;
      final w = (endOffset - startOffset) * pixelsPerHour;

      final rect = Rect.fromLTWH(x, y + 2, w, stageHeight - 4);
      if (rect.contains(position)) {
        return entry.raw;
      }
    }
    return null;
  }

  static _ParsedSchedule _parseSchedule(List<Map<String, dynamic>> schedule) {
    final entries = <_ScheduleBlock>[];
    DateTime? minTime;
    DateTime? maxTime;
    final stageSet = <String>{};

    for (final item in schedule) {
      final stageName = item['stageName'] as String? ?? '';
      final djName = item['djName'] as String? ?? '';
      final startStr = item['startTime'] as String?;
      final endStr = item['endTime'] as String?;

      if (startStr == null || endStr == null) continue;

      final start = DateTime.tryParse(startStr);
      final end = DateTime.tryParse(endStr);
      if (start == null || end == null) continue;

      stageSet.add(stageName);
      entries.add(_ScheduleBlock(
        stageName: stageName,
        djName: djName,
        startTime: start,
        endTime: end,
        raw: item,
      ));

      if (minTime == null || start.isBefore(minTime)) minTime = start;
      if (maxTime == null || end.isAfter(maxTime)) maxTime = end;
    }

    return _ParsedSchedule(
      entries: entries,
      stages: stageSet.toList(),
      minTime: minTime,
      maxTime: maxTime,
    );
  }
}

class _ParsedSchedule {
  _ParsedSchedule({
    required this.entries,
    required this.stages,
    required this.minTime,
    required this.maxTime,
  });

  final List<_ScheduleBlock> entries;
  final List<String> stages;
  final DateTime? minTime;
  final DateTime? maxTime;
}

class _ScheduleBlock {
  _ScheduleBlock({
    required this.stageName,
    required this.djName,
    required this.startTime,
    required this.endTime,
    required this.raw,
  });

  final String stageName;
  final String djName;
  final DateTime startTime;
  final DateTime endTime;
  final Map<String, dynamic> raw;
}

/// The actual painter for the schedule grid.
class EventScheduleCanvasPainter extends CustomPainter {
  EventScheduleCanvasPainter({
    required this.parsed,
    required this.leftPad,
    required this.topPad,
    required this.pixelsPerHour,
    required this.stageHeight,
  });

  final _ParsedSchedule parsed;
  final double leftPad;
  final double topPad;
  final double pixelsPerHour;
  final double stageHeight;

  static const _palette = [
    Color(0xFF6C5CE7),
    Color(0xFF00B894),
    Color(0xFFE17055),
    Color(0xFF0984E3),
    Color(0xFFFDAA5B),
    Color(0xFFE84393),
    Color(0xFF00CEC9),
    Color(0xFFD63031),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (parsed.minTime == null || parsed.maxTime == null) return;

    final gridPaint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 0.5;

    final totalMinutes = parsed.maxTime!.difference(parsed.minTime!).inMinutes;
    final totalHours = (totalMinutes / 60).ceil();

    // Draw hour gridlines and labels
    for (int h = 0; h <= totalHours; h++) {
      final x = leftPad + h * pixelsPerHour;
      canvas.drawLine(
        Offset(x, topPad),
        Offset(x, topPad + parsed.stages.length * stageHeight),
        gridPaint,
      );

      // Hour label
      final hourTime = parsed.minTime!.add(Duration(hours: h));
      final label = '${hourTime.hour.toString().padLeft(2, '0')}:00';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Color(0x99FFFFFF),
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, topPad - tp.height - 4));
    }

    // Draw stage labels and horizontal gridlines
    for (int s = 0; s < parsed.stages.length; s++) {
      final y = topPad + s * stageHeight;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width, y),
        gridPaint,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: parsed.stages[s],
          style: const TextStyle(
            color: Color(0xCCFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '..',
      )..layout(maxWidth: leftPad - 8);
      tp.paint(
        canvas,
        Offset(4, y + (stageHeight - tp.height) / 2),
      );
    }

    // Draw schedule blocks
    for (final entry in parsed.entries) {
      final stageIndex = parsed.stages.indexOf(entry.stageName);
      if (stageIndex < 0) continue;

      final startOffset =
          entry.startTime.difference(parsed.minTime!).inMinutes / 60;
      final endOffset =
          entry.endTime.difference(parsed.minTime!).inMinutes / 60;

      final x = leftPad + startOffset * pixelsPerHour;
      final y = topPad + stageIndex * stageHeight + 2;
      final w = math.max((endOffset - startOffset) * pixelsPerHour, 4.0);
      final h = stageHeight - 4;

      final color = _palette[stageIndex % _palette.length];
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        const Radius.circular(6),
      );

      canvas.drawRRect(
        rrect,
        Paint()..color = color.withValues(alpha: 0.8),
      );

      // Draw DJ name if block is wide enough
      if (w > 30) {
        final tp = TextPainter(
          text: TextSpan(
            text: entry.djName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '..',
        )..layout(maxWidth: w - 8);
        tp.paint(
          canvas,
          Offset(x + 4, y + (h - tp.height) / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant EventScheduleCanvasPainter oldDelegate) {
    return parsed != oldDelegate.parsed;
  }
}
