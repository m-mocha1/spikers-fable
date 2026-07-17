import 'entities/session_model.dart';

/// Picks the session to surface a post-session "shout-out" prompt for, or null
/// when there is none. Chooses the most recently ended session that:
///  - has already ended (`endTime` before [now]),
///  - ended within [window] (so a fresh install or a long absence doesn't
///    resurface an ancient session),
///  - the user hasn't already been prompted about ([promptedSessionIds]),
///  - still has at least one other attendee to endorse ([SessionModel.attendedIds]
///    minus [uid]).
///
/// Kept pure and free of `DateTime.now()`/persistence so the trigger logic in
/// `ShoutOutGate` stays unit-testable. [sessions] may arrive in any order — the
/// newest eligible one by `endTime` wins.
SessionModel? pickShoutOutSession({
  required List<SessionModel> sessions,
  required String uid,
  required DateTime now,
  required Set<String> promptedSessionIds,
  Duration window = const Duration(days: 7),
}) {
  SessionModel? best;
  for (final s in sessions) {
    if (!s.endTime.isBefore(now)) continue; // hasn't ended yet
    if (now.difference(s.endTime) > window) continue; // too old to bother
    if (promptedSessionIds.contains(s.id)) continue;
    if (!s.attendedIds.any((id) => id != uid)) continue; // no one to endorse
    if (best == null || s.endTime.isAfter(best.endTime)) best = s;
  }
  return best;
}
