/// Date formatting utilities for the RaveHub app.
///
/// Provides concise, user-friendly date representations used throughout the
/// feed, event listings, and profile screens.
extension DateFormattingExtensions on DateTime {
  // ---------------------------------------------------------------------------
  // Relative ("time ago") formatting
  // ---------------------------------------------------------------------------

  /// Returns a human-readable relative time string such as "just now",
  /// "5m ago", "3h ago", "2d ago", or falls back to a compact date for
  /// anything older than 7 days.
  ///
  /// The optional [now] parameter is exposed for testability.
  String toRelativeString({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(this);

    if (diff.isNegative) {
      // Future dates -- fall back to the compact format.
      return toCompactDate();
    }

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return toCompactDate();
  }

  // ---------------------------------------------------------------------------
  // Event date formatting
  // ---------------------------------------------------------------------------

  /// Formats the date for event cards and detail screens.
  ///
  /// Examples:
  /// - Same year:   `"Sat, Jun 14"`
  /// - Other year:  `"Sat, Jun 14, 2025"`
  ///
  /// The optional [now] parameter is exposed for testability.
  String toEventDateString({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final weekday = _shortWeekday(this.weekday);
    final month = _shortMonth(this.month);
    final day = this.day;

    if (year == reference.year) {
      return '$weekday, $month $day';
    }
    return '$weekday, $month $day, $year';
  }

  // ---------------------------------------------------------------------------
  // Compact date
  // ---------------------------------------------------------------------------

  /// Returns a compact date string in the format `"MM/DD/YYYY"`.
  ///
  /// Suitable for table cells and secondary labels where space is limited.
  String toCompactDate() {
    final mm = month.toString().padLeft(2, '0');
    final dd = day.toString().padLeft(2, '0');
    return '$mm/$dd/$year';
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static String _shortWeekday(int weekday) {
    const names = <int, String>{
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };
    return names[weekday] ?? '';
  }

  static String _shortMonth(int month) {
    const names = <int, String>{
      1: 'Jan',
      2: 'Feb',
      3: 'Mar',
      4: 'Apr',
      5: 'May',
      6: 'Jun',
      7: 'Jul',
      8: 'Aug',
      9: 'Sep',
      10: 'Oct',
      11: 'Nov',
      12: 'Dec',
    };
    return names[month] ?? '';
  }
}
