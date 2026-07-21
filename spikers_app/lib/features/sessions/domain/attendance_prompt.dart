import 'entities/session_model.dart';

/// Selectors for the coach "take attendance" prompt. Kept pure (no
/// `DateTime.now()` / persistence) so the trigger logic in
/// `CoachAttendanceGate` and the badge provider stay unit-testable — the same
/// shape as `pickShoutOutSession`.

/// A session needs its coach to take attendance when they own it, it has
/// already ended (recently — within [window]), attendance hasn't been taken
/// yet, and at least one player was on the roster to mark.
bool _needsAttendance(
  SessionModel s,
  String uid,
  DateTime now,
  Duration window,
) {
  if (s.coachId != uid) return false;
  if (!s.endTime.isBefore(now)) return false; // hasn't ended
  if (now.difference(s.endTime) > window) return false; // too old to nag
  if (s.attendanceConfirmed) return false; // coach already took attendance
  if (s.attendeeIds.isEmpty) return false; // nobody to mark
  return true;
}

/// Picks the single session to surface the once-per-launch take-attendance
/// prompt for, or null when there is none. The most recently ended eligible
/// session the coach hasn't already been prompted about wins. [sessions] may
/// arrive in any order.
SessionModel? pickAttendanceSession({
  required List<SessionModel> sessions,
  required String uid,
  required DateTime now,
  required Set<String> promptedSessionIds,
  Duration window = const Duration(days: 3),
}) {
  SessionModel? best;
  for (final s in sessions) {
    if (!_needsAttendance(s, uid, now, window)) continue;
    if (promptedSessionIds.contains(s.id)) continue;
    if (best == null || s.endTime.isAfter(best.endTime)) best = s;
  }
  return best;
}

/// Every session that needs the coach ([uid]) to take attendance, newest-ended
/// first — drives the "N sessions need attendance" badge/banner. Unlike
/// [pickAttendanceSession] this ignores the per-session "prompted" flag: a
/// dismissed prompt still leaves the work outstanding until it's actually done.
List<SessionModel> coachSessionsNeedingAttendance({
  required List<SessionModel> sessions,
  required String uid,
  required DateTime now,
  Duration window = const Duration(days: 3),
}) {
  final list = [
    for (final s in sessions)
      if (_needsAttendance(s, uid, now, window)) s,
  ]..sort((a, b) => b.endTime.compareTo(a.endTime));
  return list;
}
