import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/attendance_prompt.dart';
import '../../domain/entities/session_model.dart';
import '../providers/sessions_providers.dart';
import 'take_attendance_sheet.dart';

/// Wraps the home shell and, once per app launch, checks whether the signed-in
/// coach owns a recently-ended session they haven't yet taken attendance for —
/// and if so slides up [showTakeAttendanceSheet]. This is what brings the
/// after-the-whistle attendance task to the coach instead of relying on them
/// to dig into session history for it.
///
/// Mirrors [ShoutOutGate] exactly: non-blocking, skippable, and never fires
/// twice for the same session on the same device (a per-coach+session
/// SharedPreferences flag).
class CoachAttendanceGate extends ConsumerStatefulWidget {
  const CoachAttendanceGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CoachAttendanceGate> createState() =>
      _CoachAttendanceGateState();
}

class _CoachAttendanceGateState extends ConsumerState<CoachAttendanceGate> {
  /// Latches once we actually run the check with a signed-in coach, so it fires
  /// at most once per app launch regardless of how many times the user stream
  /// re-emits.
  bool _ran = false;

  String _promptKey(String uid, String sessionId) =>
      'attendance_prompted_${uid}_$sessionId';

  Future<void> _maybePrompt() async {
    if (_ran) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return; // stream not ready yet — a later emission retries
    if (!user.isCoach) return; // players never take attendance
    _ran = true;
    final uid = user.uid;
    final repo = ref.read(sessionsRepositoryProvider);

    final List<SessionModel> sessions;
    try {
      sessions = await repo.fetchCoachRecentSessions(uid);
    } catch (_) {
      return; // best-effort: a prompt is never worth surfacing an error
    }

    final prefs = await SharedPreferences.getInstance();
    final prompted = {
      for (final s in sessions)
        if (prefs.getBool(_promptKey(uid, s.id)) ?? false) s.id,
    };

    final candidate = pickAttendanceSession(
      sessions: sessions,
      uid: uid,
      now: DateTime.now(),
      promptedSessionIds: prompted,
    );
    if (candidate == null) return;

    // Mark prompted before showing, so a dismiss doesn't resurface it on the
    // next launch; the badge/banner still keeps the work discoverable until
    // it's actually done.
    await prefs.setBool(_promptKey(uid, candidate.id), true);

    if (!mounted) return;
    await showTakeAttendanceSheet(
      context,
      session: candidate,
      // Confirming here takes the session out of the "needs attendance" set, so
      // refresh the badge/banner provider — otherwise the sessions-screen
      // banner keeps showing the session we just handled.
      onSaved: () => ref.invalidate(coachAttendanceTodoProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cover both cases: the user is already available when the gate mounts
    // (post-frame), and the auth stream emits a user shortly after (listen).
    // `_maybePrompt` is idempotent via `_ran`, so at most one prompt shows.
    ref.listen(currentUserProvider, (_, _) => _maybePrompt());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
    return widget.child;
  }
}
