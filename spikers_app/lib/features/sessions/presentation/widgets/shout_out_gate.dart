import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/session_model.dart';
import '../../domain/shout_out_candidate.dart';
import '../providers/sessions_providers.dart';
import 'shout_out_sheet.dart';

/// Wraps the home shell and, once per app launch, checks whether the signed-in
/// user recently attended a session they haven't yet been prompted to endorse
/// teammates from — and if so slides up [showShoutOutSheet].
///
/// Mirrors [AppUpgradeAlert]'s "check once on the landing screen" shape. The
/// prompt is non-blocking and skippable, and never fires twice for the same
/// session on the same device (a per-user+session SharedPreferences flag, the
/// same pattern the profile milestone celebrations use).
class ShoutOutGate extends ConsumerStatefulWidget {
  const ShoutOutGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShoutOutGate> createState() => _ShoutOutGateState();
}

class _ShoutOutGateState extends ConsumerState<ShoutOutGate> {
  /// Latches once we actually run the check with a signed-in user, so it fires
  /// at most once per app launch regardless of how many times the user stream
  /// re-emits.
  bool _ran = false;

  String _promptKey(String uid, String sessionId) =>
      'shoutout_prompted_${uid}_$sessionId';

  Future<void> _maybePrompt() async {
    if (_ran) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return; // stream not ready yet — a later emission retries
    _ran = true;
    final uid = user.uid;
    final repo = ref.read(sessionsRepositoryProvider);

    final List<SessionModel> sessions;
    try {
      sessions = await repo.fetchAttendedSessions(uid);
    } catch (_) {
      return; // best-effort: a prompt is never worth surfacing an error
    }

    final prefs = await SharedPreferences.getInstance();
    final prompted = {
      for (final s in sessions)
        if (prefs.getBool(_promptKey(uid, s.id)) ?? false) s.id,
    };

    final candidate = pickShoutOutSession(
      sessions: sessions,
      uid: uid,
      now: DateTime.now(),
      promptedSessionIds: prompted,
    );
    if (candidate == null) return;

    // Skip (and mark prompted) if the user already spent both endorsement
    // slots on this session, e.g. via the session-detail roster.
    Set<String> mine;
    try {
      mine = await repo.watchMyEndorsements(candidate.id, uid).first;
    } catch (_) {
      mine = const {};
    }
    final others = candidate.attendedIds.where((id) => id != uid).toSet();
    await prefs.setBool(_promptKey(uid, candidate.id), true);
    if (mine.length >= 2 || others.every(mine.contains)) return;

    if (!mounted) return;
    await showShoutOutSheet(context, session: candidate);
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
