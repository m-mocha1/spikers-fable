import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/core/utils/attendance_streak.dart';

void main() {
  // Wednesday 2026-07-01. The containing (Sunday-based) week is
  // Sun 2026-06-28 … Sat 2026-07-04.
  final now = DateTime(2026, 7, 1, 12);

  // A stable in-week day (Monday 2026-06-29 18:00) shifted back N whole weeks.
  DateTime weeksAgo(int weeks) {
    final monday = DateTime(2026, 6, 29, 18);
    return monday.subtract(Duration(days: 7 * weeks));
  }

  group('AttendanceStreak.weeklyStreak', () {
    test('empty history → 0', () {
      expect(AttendanceStreak.weeklyStreak(const [], now: now), 0);
    });

    test('attended only this week → 1', () {
      expect(
        AttendanceStreak.weeklyStreak([weeksAgo(0)], now: now),
        1,
      );
    });

    test('this week + last week → 2', () {
      expect(
        AttendanceStreak.weeklyStreak([weeksAgo(0), weeksAgo(1)], now: now),
        2,
      );
    });

    test('grace: nothing yet this week, streak continues from last week', () {
      expect(
        AttendanceStreak.weeklyStreak(
          [weeksAgo(1), weeksAgo(2), weeksAgo(3)],
          now: now,
        ),
        3,
      );
    });

    test('no grace beyond one week: last attended two weeks ago → 0', () {
      expect(
        AttendanceStreak.weeklyStreak([weeksAgo(2), weeksAgo(3)], now: now),
        0,
      );
    });

    test('gap breaks the streak', () {
      // Attended this week and 2 weeks ago, but skipped last week.
      expect(
        AttendanceStreak.weeklyStreak([weeksAgo(0), weeksAgo(2)], now: now),
        1,
      );
    });

    test('multiple sessions in one week count once', () {
      expect(
        AttendanceStreak.weeklyStreak(
          [
            weeksAgo(0),
            weeksAgo(0).add(const Duration(days: 2)),
            weeksAgo(1),
          ],
          now: now,
        ),
        2,
      );
    });

    test('week runs Sunday–Saturday: Sunday belongs to the new week', () {
      // now is Wed 2026-07-01; that week began Sun 2026-06-28.
      // Sat 2026-06-27 is the PREVIOUS week, Sun 2026-06-28 the current one.
      final saturday = DateTime(2026, 6, 27, 20);
      final sunday = DateTime(2026, 6, 28, 20);
      expect(
        AttendanceStreak.weeklyStreak([sunday], now: now),
        1,
        reason: 'Sunday session is in the current week',
      );
      expect(
        AttendanceStreak.weeklyStreak([saturday, sunday], now: now),
        2,
        reason: 'Saturday is the tail of the previous week',
      );
    });

    test('order does not matter', () {
      final shuffled = [weeksAgo(2), weeksAgo(0), weeksAgo(1)];
      expect(AttendanceStreak.weeklyStreak(shuffled, now: now), 3);
    });
  });
}
