/// Weekly attendance streak computation (pure — trivially unit-testable).
///
/// A "week" runs Sunday through Saturday (the Israeli week — the club is in
/// Jerusalem). The streak is the number of consecutive weeks with at least one
/// attended session, counting backward from the current week. The current week
/// gets grace: if the player hasn't attended *yet* this week, the streak keeps
/// counting from last week instead of resetting mid-week.
class AttendanceStreak {
  AttendanceStreak._();

  /// Number of consecutive attended weeks ending at the current (or, under
  /// grace, the previous) week. [now] is injectable for tests.
  static int weeklyStreak(List<DateTime> attendedTimes, {DateTime? now}) {
    if (attendedTimes.isEmpty) return 0;
    final current = _weekIndex(now ?? DateTime.now());
    final weeks = attendedTimes.map(_weekIndex).toSet();

    // Anchor on the current week, or on last week if this week is still empty
    // (grace). Anything older means the streak is broken.
    final int anchor;
    if (weeks.contains(current)) {
      anchor = current;
    } else if (weeks.contains(current - 1)) {
      anchor = current - 1;
    } else {
      return 0;
    }

    var streak = 0;
    for (var week = anchor; weeks.contains(week); week--) {
      streak++;
    }
    return streak;
  }

  /// Index of the Sunday-based week containing [time]. Consecutive weeks have
  /// consecutive indices, which is all the streak walk above needs.
  static int _weekIndex(DateTime time) {
    // Normalize to local midnight so DST shifts can't bleed across a boundary.
    final day = DateTime(time.year, time.month, time.day);
    // DateTime.weekday: Mon=1 … Sun=7 → days since the week's Sunday.
    final daysSinceSunday = day.weekday % 7;
    final sunday = day.subtract(Duration(days: daysSinceSunday));
    // Days since the Unix epoch, then group by 7. The epoch anchor is
    // arbitrary — only differences between indices matter.
    return sunday.difference(DateTime(1970, 1, 4)).inDays ~/ 7;
  }
}
