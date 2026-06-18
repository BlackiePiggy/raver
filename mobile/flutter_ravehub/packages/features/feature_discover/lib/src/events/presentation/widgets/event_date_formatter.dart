import 'package:raver_models/raver_models.dart';

class EventDateFormatter {
  const EventDateFormatter._();

  static String range(WebEvent event) {
    final formatted = rangeFromStrings(event.startDate, event.endDate);
    final timezone = timezoneLabel(event.schedule);
    if (timezone.isEmpty) return formatted;
    return '$formatted · $timezone';
  }

  static String rangeFromStrings(String start, String end) {
    final startParts = _DateParts.parse(start);
    final endParts = _DateParts.parse(end);

    if (startParts == null && endParts == null) return '';
    if (startParts == null) return endParts!.dateText;
    if (endParts == null) return startParts.dateTimeText;

    if (startParts.sameDate(endParts)) {
      if (startParts.hasDisplayTime && endParts.hasDisplayTime) {
        return '${startParts.dateText} ${startParts.timeText}-${endParts.timeText}';
      }
      return startParts.dateText;
    }

    return '${startParts.dateTimeText} ~ ${endParts.dateTimeText}';
  }

  static String timezoneLabel(WebEventSchedule? schedule) {
    if (schedule == null) return '';
    final name = schedule.timezoneName.trim();
    final id = schedule.timezoneId.trim();
    if (name.isNotEmpty && id.isNotEmpty) return '$name ($id)';
    if (name.isNotEmpty) return name;
    return id;
  }
}

class _DateParts {
  const _DateParts({
    required this.year,
    required this.month,
    required this.day,
    this.hour,
    this.minute,
  });

  final String year;
  final String month;
  final String day;
  final String? hour;
  final String? minute;

  static final _datePattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[T\s](\d{2}):(\d{2}))?',
  );

  static _DateParts? parse(String value) {
    final match = _datePattern.firstMatch(value.trim());
    if (match == null) return null;
    return _DateParts(
      year: match.group(1)!,
      month: match.group(2)!,
      day: match.group(3)!,
      hour: match.group(4),
      minute: match.group(5),
    );
  }

  bool get hasDisplayTime {
    if (hour == null || minute == null) return false;
    return hour != '00' || minute != '00';
  }

  String get dateText => '$year-$month-$day';

  String get timeText => hasDisplayTime ? '$hour:$minute' : '';

  String get dateTimeText {
    if (!hasDisplayTime) return dateText;
    return '$dateText $timeText';
  }

  bool sameDate(_DateParts other) =>
      year == other.year && month == other.month && day == other.day;
}
