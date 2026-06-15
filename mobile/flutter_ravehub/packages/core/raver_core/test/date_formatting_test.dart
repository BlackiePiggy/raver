import 'package:raver_core/raver_core.dart';
import 'package:test/test.dart';

void main() {
  group('DateFormattingExtensions', () {
    group('toRelativeString', () {
      test('returns "just now" for less than 60 seconds ago', () {
        final now = DateTime(2026, 6, 14, 12, 0, 0);
        final date = DateTime(2026, 6, 14, 11, 59, 30);
        expect(date.toRelativeString(now: now), equals('just now'));
      });

      test('returns "just now" for exactly 0 seconds ago', () {
        final now = DateTime(2026, 6, 14, 12, 0, 0);
        expect(now.toRelativeString(now: now), equals('just now'));
      });

      test('returns minutes ago for 1-59 minutes', () {
        final now = DateTime(2026, 6, 14, 12, 0, 0);
        final oneMinAgo = DateTime(2026, 6, 14, 11, 59, 0);
        expect(oneMinAgo.toRelativeString(now: now), equals('1m ago'));

        final thirtyMinAgo = DateTime(2026, 6, 14, 11, 30, 0);
        expect(thirtyMinAgo.toRelativeString(now: now), equals('30m ago'));

        final fiftyNineMinAgo = DateTime(2026, 6, 14, 11, 1, 0);
        expect(fiftyNineMinAgo.toRelativeString(now: now), equals('59m ago'));
      });

      test('returns hours ago for 1-23 hours', () {
        final now = DateTime(2026, 6, 14, 12, 0, 0);
        final oneHourAgo = DateTime(2026, 6, 14, 11, 0, 0);
        expect(oneHourAgo.toRelativeString(now: now), equals('1h ago'));

        final fiveHoursAgo = DateTime(2026, 6, 14, 7, 0, 0);
        expect(fiveHoursAgo.toRelativeString(now: now), equals('5h ago'));
      });

      test('returns days ago for 1-6 days', () {
        final now = DateTime(2026, 6, 14, 12, 0, 0);
        final oneDayAgo = DateTime(2026, 6, 13, 12, 0, 0);
        expect(oneDayAgo.toRelativeString(now: now), equals('1d ago'));

        final sixDaysAgo = DateTime(2026, 6, 8, 12, 0, 0);
        expect(sixDaysAgo.toRelativeString(now: now), equals('6d ago'));
      });

      test('returns compact date for 7+ days ago', () {
        final now = DateTime(2026, 6, 14, 12, 0, 0);
        final sevenDaysAgo = DateTime(2026, 6, 7, 12, 0, 0);
        // Should fall back to compact date (MM/DD/YYYY)
        expect(sevenDaysAgo.toRelativeString(now: now), equals('06/07/2026'));
      });

      test('returns compact date for future dates', () {
        final now = DateTime(2026, 6, 14, 12, 0, 0);
        final future = DateTime(2026, 6, 15, 12, 0, 0);
        // Future dates fall back to compact format
        expect(future.toRelativeString(now: now), equals('06/15/2026'));
      });
    });

    group('toEventDateString', () {
      test('same year omits year', () {
        final now = DateTime(2026, 6, 14);
        // June 14, 2026 is a Sunday
        final date = DateTime(2026, 6, 14);
        expect(date.toEventDateString(now: now), equals('Sun, Jun 14'));
      });

      test('different year includes year', () {
        final now = DateTime(2026, 6, 14);
        // Jan 15, 2025 is a Wednesday
        final date = DateTime(2025, 1, 15);
        expect(date.toEventDateString(now: now), equals('Wed, Jan 15, 2025'));
      });

      test('formats all weekdays correctly', () {
        // Mon June 8, 2026
        final mon = DateTime(2026, 6, 8);
        expect(
          mon.toEventDateString(now: DateTime(2026, 6, 14)),
          equals('Mon, Jun 8'),
        );

        // Tue June 9, 2026
        final tue = DateTime(2026, 6, 9);
        expect(
          tue.toEventDateString(now: DateTime(2026, 6, 14)),
          equals('Tue, Jun 9'),
        );

        // Wed June 10, 2026
        final wed = DateTime(2026, 6, 10);
        expect(
          wed.toEventDateString(now: DateTime(2026, 6, 14)),
          equals('Wed, Jun 10'),
        );

        // Thu June 11, 2026
        final thu = DateTime(2026, 6, 11);
        expect(
          thu.toEventDateString(now: DateTime(2026, 6, 14)),
          equals('Thu, Jun 11'),
        );

        // Fri June 12, 2026
        final fri = DateTime(2026, 6, 12);
        expect(
          fri.toEventDateString(now: DateTime(2026, 6, 14)),
          equals('Fri, Jun 12'),
        );

        // Sat June 13, 2026
        final sat = DateTime(2026, 6, 13);
        expect(
          sat.toEventDateString(now: DateTime(2026, 6, 14)),
          equals('Sat, Jun 13'),
        );

        // Sun June 14, 2026
        final sun = DateTime(2026, 6, 14);
        expect(
          sun.toEventDateString(now: DateTime(2026, 6, 14)),
          equals('Sun, Jun 14'),
        );
      });

      test('formats all months correctly', () {
        final now = DateTime(2026, 12, 31);
        for (var m = 1; m <= 12; m++) {
          final date = DateTime(2026, m, 1);
          final result = date.toEventDateString(now: now);
          // Each result should contain a short month name
          expect(result, isNotEmpty);
        }
        expect(
          DateTime(2026, 1, 1).toEventDateString(now: now),
          contains('Jan'),
        );
        expect(
          DateTime(2026, 12, 25).toEventDateString(now: now),
          contains('Dec'),
        );
      });
    });

    group('toCompactDate', () {
      test('formats as MM/DD/YYYY', () {
        final date = DateTime(2026, 6, 14);
        expect(date.toCompactDate(), equals('06/14/2026'));
      });

      test('pads single-digit month with leading zero', () {
        final date = DateTime(2026, 1, 15);
        expect(date.toCompactDate(), equals('01/15/2026'));
      });

      test('pads single-digit day with leading zero', () {
        final date = DateTime(2026, 12, 5);
        expect(date.toCompactDate(), equals('12/05/2026'));
      });

      test('handles first day of year', () {
        final date = DateTime(2026, 1, 1);
        expect(date.toCompactDate(), equals('01/01/2026'));
      });

      test('handles last day of year', () {
        final date = DateTime(2026, 12, 31);
        expect(date.toCompactDate(), equals('12/31/2026'));
      });

      test('handles leap day', () {
        final date = DateTime(2024, 2, 29);
        expect(date.toCompactDate(), equals('02/29/2024'));
      });
    });
  });
}
