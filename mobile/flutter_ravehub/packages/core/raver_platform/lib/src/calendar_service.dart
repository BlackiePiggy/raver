import 'package:url_launcher/url_launcher.dart';

/// Adds events to the device calendar via URL schemes.
///
/// This is a lightweight, dependency-free approach that works on both
/// platforms without requiring calendar-specific plugins. For richer
/// calendar integration, consider adding `device_calendar` in the future.
class CalendarService {
  const CalendarService._();

  /// Opens the device calendar pre-populated with the given event details.
  ///
  /// Uses a Google Calendar web intent as a universal fallback that works on
  /// both iOS and Android. On iOS the system intercepts calendar URLs and
  /// offers to add the event natively.
  static Future<void> addEventToCalendar({
    required String title,
    required DateTime startDate,
    DateTime? endDate,
    String? location,
    String? description,
  }) async {
    final effectiveEnd = endDate ?? startDate.add(const Duration(hours: 2));

    final queryParams = <String, String>{
      'action': 'TEMPLATE',
      'text': title,
      'dates': '${_formatDateTime(startDate)}/${_formatDateTime(effectiveEnd)}',
    };

    if (location != null && location.isNotEmpty) {
      queryParams['location'] = location;
    }
    if (description != null && description.isNotEmpty) {
      queryParams['details'] = description;
    }

    final uri = Uri.https('calendar.google.com', '/calendar/event', queryParams);

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Formats a [DateTime] into the `YYYYMMDDTHHmmssZ` format expected by
  /// the Google Calendar URL scheme.
  static String _formatDateTime(DateTime dt) {
    final utc = dt.toUtc();
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    return '${year}${month}${day}T${hour}${minute}${second}Z';
  }
}
