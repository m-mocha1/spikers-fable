import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_gradients.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/celebration.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/injured_icon.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/repositories/sessions_repository.dart';
import '../providers/sessions_providers.dart';
import '../utils/session_error_l10n.dart';

/// What the viewer's membership optimistically becomes the instant they tap
/// join/leave, shown before the Cloud Function + live snapshot confirm.
enum _OptimisticMembership { none, attendee, waitlist }

class SessionDetailScreen extends ConsumerStatefulWidget {
  /// Either a full [session] (from list taps) or just a [sessionId]
  /// (from notification taps) — never both.
  final SessionModel? session;
  final String? sessionId;
  const SessionDetailScreen({super.key, this.session, this.sessionId});

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  SessionModel? _session;
  String _sessionId = '';
  StreamSubscription? _sub;
  Map<String, PublicProfile> _userMap = {};
  List<String> _lastFetchedIds = [];
  List<String> _lastAttendedIds = const [];
  String _coachName = '';
  bool _isArchived = false;
  bool _archiveTriggered = false;
  Timer? _archiveTimer;

  // Join/leave feels instant: the button flips to its target state the moment
  // the user taps ([_optimistic]) while the Cloud Function runs in the
  // background; the live snapshot then confirms and clears the override.
  // [_actionInFlight] only blocks a second overlapping request — there's no
  // spinner and no cooldown, so nothing sits between the tap and the change.
  _OptimisticMembership? _optimistic;
  bool _actionInFlight = false;
  bool _isCancelling = false;

  // Optimistic overrides for coach attendance toggles (keyed by attendee uid)
  // and peer endorsements — applied the instant the icon is tapped, then
  // reconciled by the live snapshot / endorsements stream.
  final Map<String, bool> _optimisticAttended = {};
  final Set<String> _optimisticEndorsed = {};

  SessionsRepository get _repo => ref.read(sessionsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    final arg = widget.session;
    if (arg != null) {
      _session = arg;
      _sessionId = arg.id;
      // Seed synchronously from the profile cache so rows for anyone seen
      // before render on the very first frame; _fetchProfiles then swaps in
      // the fresh copies.
      _userMap = _repo.cachedProfiles(_profileIds(arg));
      _coachName = _userMap[arg.coachId]?.name ?? '';
      _fetchProfiles(arg);
    } else if (widget.sessionId != null) {
      _sessionId = widget.sessionId!;
    }
    if (_sessionId.isEmpty) {
      // No valid session id passed — bail out instead of querying doc('').
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    _listenToSession();
  }

  void _listenToSession() {
    _sub = _repo.watchSession(_sessionId).listen((session) async {
      if (session == null) {
        final archived = await _repo.watchArchivedSession(_sessionId).first;
        if (archived != null) {
          _switchToHistory();
          return;
        }
        if (!mounted) return;
        final l = AppLocalizations.of(context)!;
        Navigator.of(context).pop();
        showAppSnackbar(l.sessionCancelled);
        return;
      }
      if (!mounted) return;
      setState(() {
        _session = session;
        _reconcileOptimistic(session);
        _reconcileAttendance(session);
      });

      _scheduleArchival(session);
      _refreshDerived(session);
    });
  }

  void _switchToHistory() {
    _sub?.cancel();
    if (!mounted) return;
    setState(() => _isArchived = true);
    _sub = _repo.watchArchivedSession(_sessionId).listen((session) {
      if (session == null || !mounted) return;
      setState(() => _session = session);
      _refreshDerived(session);
    });
  }

  void _refreshDerived(SessionModel session) {
    // A change in attendedIds means attendanceCounts changed server-side, so
    // force a refetch to refresh the per-row counters. (Refetching only the
    // toggled uid would save reads; not worth the diff logic yet.)
    final sortedAttended = [...session.attendedIds]..sort();
    if (!_listsEqual(sortedAttended, _lastAttendedIds)) {
      _lastFetchedIds = const [];
      _lastAttendedIds = sortedAttended;
    }
    _fetchProfiles(session);
  }

  void _scheduleArchival(SessionModel session) {
    if (_archiveTriggered) return;
    if (session.isExpired) {
      _triggerArchival();
      return;
    }
    _archiveTimer?.cancel();
    final delay = session.endTime.difference(DateTime.now());
    if (delay.isNegative) {
      _triggerArchival();
      return;
    }
    _archiveTimer = Timer(delay, _triggerArchival);
  }

  Future<void> _triggerArchival() async {
    if (_archiveTriggered) return;
    _archiveTriggered = true;
    await _repo.archiveExpiredNow();
  }

  /// Everyone this screen displays a profile for — attendees, waitlist and
  /// the coach — deduped so they resolve in one batched read.
  List<String> _profileIds(SessionModel session) => {
        ...session.attendeeIds,
        ...session.waitlistIds,
        if (session.coachId.isNotEmpty) session.coachId,
      }.toList();

  /// Stale-while-revalidate profile load: cached rows appear immediately,
  /// then one fresh batched fetch replaces the whole map (a full replace so
  /// players removed from the session drop out).
  Future<void> _fetchProfiles(SessionModel session) async {
    final ids = _profileIds(session);
    final sorted = [...ids]..sort();
    if (_listsEqual(sorted, _lastFetchedIds)) return;
    _lastFetchedIds = sorted;

    if (ids.isEmpty) {
      if (mounted) setState(() => _userMap = {});
      return;
    }

    final seeded = _repo.cachedProfiles(ids);
    if (seeded.keys.any((uid) => !_userMap.containsKey(uid)) && mounted) {
      setState(() {
        _userMap = {..._userMap, ...seeded};
        _coachName = _userMap[session.coachId]?.name ?? _coachName;
      });
    }

    try {
      final fresh = await _repo.fetchPublicProfiles(ids);
      if (!mounted) return;
      setState(() {
        _userMap = fresh;
        _coachName = fresh[session.coachId]?.name ?? '';
      });
    } catch (_) {
      // Keep the seeded/previous map; unresolved rows stay as placeholders.
    }
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _archiveTimer?.cancel();
    super.dispose();
  }

  /// Once the live snapshot reflects what we optimistically showed, drop the
  /// override so the UI is driven purely by the server truth again (no flicker,
  /// since the snapshot now matches what the button already displays).
  void _reconcileOptimistic(SessionModel session) {
    final opt = _optimistic;
    if (opt == null) return;
    final uid = ref.read(currentUserProvider).value?.uid ?? '';
    final server = session.isJoinedBy(uid)
        ? _OptimisticMembership.attendee
        : session.isWaitlistedBy(uid)
            ? _OptimisticMembership.waitlist
            : _OptimisticMembership.none;
    if (server == opt) _optimistic = null;
  }

  /// Drop any attendance override the live snapshot now agrees with.
  void _reconcileAttendance(SessionModel session) {
    if (_optimisticAttended.isEmpty) return;
    _optimisticAttended.removeWhere(
      (uid, attended) => session.attendedIds.contains(uid) == attended,
    );
  }

  /// Effective attendance = server truth with the pending optimistic toggles
  /// applied on top, so the checkmarks and the count stay in sync instantly.
  Set<String> _effectiveAttended(SessionModel session) {
    final set = session.attendedIds.toSet();
    _optimisticAttended.forEach((uid, attended) {
      if (attended) {
        set.add(uid);
      } else {
        set.remove(uid);
      }
    });
    return set;
  }

  Future<void> _join(AppLocalizations l) async {
    if (_actionInFlight) return;
    final session = _session!;
    // Optimistic outcome read from the current snapshot: a free spot unless
    // the session is already full (then it's a waitlist join).
    final willWaitlist = session.isFull;
    setState(() {
      _actionInFlight = true;
      _optimistic = willWaitlist
          ? _OptimisticMembership.waitlist
          : _OptimisticMembership.attendee;
    });
    // Instant feedback — fired before the round-trip so the tap lands
    // immediately. The button has already flipped via [_optimistic] above.
    if (willWaitlist) {
      HapticFeedback.selectionClick();
      showAppSnackbar(l.waitlistedSnack);
    } else {
      HapticFeedback.mediumImpact();
      if (mounted) {
        showCelebration(
          context,
          icon: Icons.how_to_reg_rounded,
          grand: true,
          dim: true,
        );
      }
      showAppSnackbar('${l.joinedSuccess} 🏐');
    }
    try {
      final result = await _repo.join(session.id);
      if (!mounted) return;
      // Reconcile the rare race where the last spot vanished between our
      // snapshot and the server transaction (optimistic "joined", actually
      // waitlisted, or vice-versa). 'already_*' need no change.
      if (result == JoinResult.waitlisted && !willWaitlist) {
        setState(() => _optimistic = _OptimisticMembership.waitlist);
        showAppSnackbar(l.waitlistedSnack);
      } else if (result == JoinResult.joined && willWaitlist) {
        setState(() => _optimistic = _OptimisticMembership.attendee);
      }
    } on SessionActionException catch (e) {
      if (mounted) setState(() => _optimistic = null); // roll back the flip
      showAppSnackbar(joinErrorMessage(l, e.code));
    } catch (_) {
      if (mounted) setState(() => _optimistic = null);
      showAppSnackbar(l.unknownError);
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _leave(AppLocalizations l) async {
    if (_actionInFlight) return;
    final session = _session!;
    setState(() {
      _actionInFlight = true;
      _optimistic = _OptimisticMembership.none;
    });
    // Instant feedback — a distinct, muted-red logout burst so leaving reads
    // clearly different from the celebratory (gold) join.
    HapticFeedback.selectionClick();
    if (mounted) {
      showCelebration(
        context,
        icon: Icons.logout_rounded,
        accent: AppColors.redMuted,
        grand: true,
        dim: true,
      );
    }
    try {
      await _repo.leave(session.id);
    } catch (_) {
      if (mounted) setState(() => _optimistic = null); // roll back the flip
      showAppSnackbar(l.unknownError);
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _markAttended(String userId, bool attended) async {
    final l = AppLocalizations.of(context)!;
    // Flip the checkmark (and the attended count) instantly; the Cloud Function
    // + live snapshot confirm behind it.
    setState(() => _optimisticAttended[userId] = attended);
    HapticFeedback.lightImpact();
    try {
      await _repo.markAttended(_session!.id, userId, attended);
    } catch (_) {
      if (mounted) setState(() => _optimisticAttended.remove(userId)); // undo
      showAppSnackbar(l.unknownError);
    }
  }

  Future<void> _endorse(String userId, String name) async {
    final l = AppLocalizations.of(context)!;
    // Flip the button to "endorsed" and celebrate the instant they tap; the
    // write is idempotent server-side and the stream keeps it endorsed.
    setState(() => _optimisticEndorsed.add(userId));
    HapticFeedback.lightImpact();
    if (mounted) showCelebration(context, dim: true);
    showAppSnackbar(l.endorsedPlayer(name));
    try {
      await _repo.endorse(_session!.id, userId);
    } on SessionActionException catch (_) {
      // e.g. session not ended, or the 2-per-session cap reached — the UI
      // gates these already, so this is a defensive fallback.
      if (mounted) setState(() => _optimisticEndorsed.remove(userId)); // undo
      showAppSnackbar(l.endorseFailed);
    } catch (_) {
      if (mounted) setState(() => _optimisticEndorsed.remove(userId));
      showAppSnackbar(l.unknownError);
    }
  }

  Future<void> _removeAttendee(String userId, String name) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDeleteConfirm(
      context,
      title: l.removePlayer,
      message: l.confirmRemovePlayer(name),
      confirmLabel: l.remove,
      cancelLabel: l.cancel,
    );
    if (!confirmed) return;
    try {
      await _repo.removeAttendee(_session!.id, userId);
    } on SessionActionException catch (_) {
      showAppSnackbar(l.unknownError);
    } catch (_) {
      showAppSnackbar(l.unknownError);
    }
  }

  Future<void> _confirmCancel(AppLocalizations l) async {
    if (_isCancelling) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.navyLight,
        title: Text(l.confirmCancelSession),
        content: Text(l.confirmCancelMessage),
        actions: [
          Builder(
            builder: (dialogCtx) {
              return TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: Text(l.no),
              );
            },
          ),
          Builder(
            builder: (dialogCtx) {
              return TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: Text(
                  l.yes,
                  style: const TextStyle(color: AppColors.errorRed),
                ),
              );
            },
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      await _repo.cancel(_session!.id);
      // Success navigation + snackbar are driven by the session snapshot
      // listener (null branch) so they fire exactly once, regardless of
      // which path observes the delete first.
    } on SessionActionException catch (e) {
      showAppSnackbar(cancelErrorMessage(l, e.code));
    } catch (_) {
      showAppSnackbar(l.unknownError);
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _editCapacity(AppLocalizations l) async {
    final session = _session!;
    final curMax = session.maxPlayers;
    final curWait = session.waitlistSize;

    final result = await showDialog<(int, int)>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _EditCapacityDialog(
        currentMax: curMax,
        currentWaitlist: curWait,
        l: l,
      ),
    );

    if (!mounted || result == null) return;

    final (newMax, newWait) = result;

    // Nothing changed — skip the round-trip; otherwise the server would
    // reject with 'Nothing to update' and the user would see a misleading
    // error snackbar.
    if (newMax == curMax && newWait == curWait) return;

    try {
      await _repo.updateCapacity(
        session.id,
        newMaxPlayers: newMax == curMax ? null : newMax,
        newWaitlistSize: newWait == curWait ? null : newWait,
      );
    } on SessionActionException catch (e) {
      // Defer past the current frame so an in-flight rebuild from the
      // Firestore listener can settle before the snackbar mounts into
      // the Overlay (prevents _dependents.isEmpty teardown races).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showAppSnackbar(capacityErrorMessage(l, e.code));
      });
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showAppSnackbar(l.unknownError);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return const Scaffold(body: LoadingView());
    }

    final l = AppLocalizations.of(context)!;
    final me = ref.watch(currentUserProvider).value;
    final uid = me?.uid ?? '';
    final isCoach = me?.isCoach ?? false;
    final isOwner = session.coachId == uid;
    // Prefer the optimistic override so the button reflects a just-tapped
    // join/leave instantly; fall back to the live session doc otherwise.
    final bool isJoined;
    final bool isWaitlisted;
    switch (_optimistic) {
      case _OptimisticMembership.attendee:
        isJoined = true;
        isWaitlisted = false;
      case _OptimisticMembership.waitlist:
        isJoined = false;
        isWaitlisted = true;
      case _OptimisticMembership.none:
        isJoined = false;
        isWaitlisted = false;
      case null:
        isJoined = session.isJoinedBy(uid);
        isWaitlisted = session.isWaitlistedBy(uid);
    }
    final canChat = isJoined || isWaitlisted || (isCoach && isOwner);

    // Endorsements: a viewer may endorse fellow attendees if they themselves
    // attended, or they're staff (coach/admin) — mirrors the server-side gate.
    // endorsedIds flips each button to its "endorsed" state; optimistic
    // endorsements are unioned in so a just-tapped button stays filled.
    final endorsedIds = {
      ...?ref.watch(myEndorsementsProvider(session.id)).value,
      ..._optimisticEndorsed,
    };
    // Server attendance with the pending optimistic toggles applied on top.
    final attendedIds = _effectiveAttended(session);
    final viewerAttended = attendedIds.contains(uid);
    // Endorsements can only be given once the session has ended (i.e. from
    // history). Server enforces the same rule in endorsePlayer.
    final viewerCanEndorse =
        uid.isNotEmpty && session.isExpired && (viewerAttended || isCoach);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          session.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (canChat)
            _ChatBadgeIcon(
              sessionId: session.id,
              tooltip: l.chat,
              onTap: () => context.push(
                Routes.sessionChat,
                extra: {'id': session.id, 'title': session.title},
              ),
            ),
          if (isCoach && !session.isOngoing && !_isArchived)
            TextButton(
              onPressed: _isCancelling ? null : () => _confirmCancel(l),
              child: _isCancelling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: AppColors.gold,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      l.cancel,
                      style: const TextStyle(color: AppColors.errorRed),
                    ),
            ),
        ],
      ),
      body: GradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The countdown clock sits on the session art and IS the Hero
              // landing pad — kept OUTSIDE the staggered fade below so the flight
              // lands cleanly.
              _CountdownCard(session: session, l: l),
              const SizedBox(height: 20),
              ...[
                    _InfoSection(session: session, l: l, coachName: _coachName),
                    const SizedBox(height: 20),
                    _AttendeesSection(
                      session: session,
                      l: l,
                      userMap: _userMap,
                      attendedIds: attendedIds,
                      isCoach: isCoach,
                      canManage: isCoach,
                      viewerUid: uid,
                      viewerCanEndorse: viewerCanEndorse,
                      endorsedIds: endorsedIds,
                      onToggleAttended: _markAttended,
                      onRemove: _removeAttendee,
                      onEndorse: _endorse,
                      onEditCapacity: () => _editCapacity(l),
                    ),
                    const SizedBox(height: 30),
                    // Coaches/admins own sessions but may also play in them, so the
                    // Join button is shown to everyone — owners included.
                    _JoinButton(
                      session: session,
                      isJoined: isJoined,
                      isWaitlisted: isWaitlisted,
                      onJoin: () => _join(l),
                      onLeave: () => _leave(l),
                      l: l,
                    ),
                  ]
                  // Image first: let the hero banner land (heroSettle), then
                  // reveal each section with a fade + small upward drift.
                  .animate(
                    delay: AppMotion.heroSettle,
                    interval: AppMotion.stagger,
                  )
                  .fadeIn(duration: AppMotion.normal, curve: AppMotion.enter)
                  .moveY(
                    begin: AppMotion.revealShift,
                    end: 0,
                    curve: AppMotion.enter,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The countdown "clock" laid over the session artwork. The art is the Hero
/// landing pad (pure art, so the flight from [SessionCard] stays clean); the
/// status label + timer overlay on top, centered.
class _CountdownCard extends StatelessWidget {
  final SessionModel session;
  final AppLocalizations l;
  const _CountdownCard({required this.session, required this.l});

  @override
  Widget build(BuildContext context) {
    final asset = AppAssets
        .cardDesigns[session.designIndex % AppAssets.cardDesigns.length];
    return SizedBox(
      height: 150,
      width: double.infinity,
      // Clip the whole panel so the veil / frame follow the rounded image
      // corners instead of squaring them off.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Hero art landing pad — pure art + scrim, matching the card's Hero.
            Hero(
              tag: 'session_art_${session.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(asset, fit: BoxFit.cover),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppGradients.cardScrim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Uniform veil so the centered timer stays legible over any design.
            ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
            // Gold ring to keep the old clock card's framing.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            // Status label + timer, centered over the art — reveals with a
            // fade + pop once the hero art has settled (heroSettle delay).
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child:
                  Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            session.isExpired
                                ? l.sessionEnded.toUpperCase()
                                : session.isOngoing
                                ? l.ongoing.toUpperCase()
                                : l.upcoming.toUpperCase(),
                            style: TextStyle(
                              color: session.isExpired || session.isOngoing
                                  ? AppColors.success
                                  : AppColors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (session.isExpired)
                            Text(
                              l.sessionEndedSubtitle,
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          else
                            _CountdownTimer(session: session),
                        ],
                      )
                      .animate(delay: AppMotion.heroSettle)
                      .fadeIn(
                        duration: AppMotion.normal,
                        curve: AppMotion.enter,
                      )
                      .scale(
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1, 1),
                        alignment: Alignment.center,
                        duration: AppMotion.normal,
                        curve: Curves.easeOutBack,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownTimer extends StatelessWidget {
  final SessionModel session;
  const _CountdownTimer({required this.session});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (ctx, _) {
        final now = DateTime.now();
        Duration diff;
        if (session.isUpcoming) {
          diff = session.startTime.difference(now);
        } else if (session.isOngoing) {
          diff = session.endTime.difference(now);
        } else {
          diff = Duration.zero;
        }
        final h = diff.inHours.toString().padLeft(2, '0');
        final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
        return Text(
          '$h:$m:$s',
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 42,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        );
      },
    );
  }
}

class _InfoSection extends StatelessWidget {
  final SessionModel session;
  final AppLocalizations l;
  final String coachName;
  const _InfoSection({
    required this.session,
    required this.l,
    required this.coachName,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE, MMM d  •  HH:mm');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.person_outline,
            label: l.coachLabel,
            value: coachName,
          ),
          const Divider(height: 20),
          _DetailRow(
            icon: Icons.location_on_outlined,
            label: l.location,
            value: session.location,
          ),
          const Divider(height: 20),
          _DetailRow(
            icon: Icons.play_arrow_outlined,
            label: l.startTime,
            value: fmt.format(session.startTime),
          ),
          const Divider(height: 20),
          _DetailRow(
            icon: Icons.stop_outlined,
            label: l.endTime,
            value: fmt.format(session.endTime),
          ),
          const Divider(height: 20),
          _DetailRow(
            icon: Icons.cake_outlined,
            label: l.ageRange,
            value: '${session.minAge} – ${session.maxAge} ${l.years}',
          ),
          const Divider(height: 20),
          _DetailRow(
            icon: Icons.people_outline,
            label: l.gender,
            value: session.gender == 'male'
                ? l.male
                : session.gender == 'female'
                ? l.female
                : l.genderMixed,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.gold),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(color: AppColors.grey, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _AttendeesSection extends StatelessWidget {
  final SessionModel session;
  final AppLocalizations l;
  final Map<String, PublicProfile> userMap;
  final Set<String> attendedIds;
  final bool isCoach;
  final bool canManage;
  final String viewerUid;
  final bool viewerCanEndorse;
  final Set<String> endorsedIds;
  final void Function(String uid, bool attended) onToggleAttended;
  final void Function(String uid, String name) onRemove;
  final void Function(String uid, String name) onEndorse;
  final VoidCallback onEditCapacity;
  const _AttendeesSection({
    required this.session,
    required this.l,
    required this.userMap,
    required this.attendedIds,
    required this.isCoach,
    required this.canManage,
    required this.viewerUid,
    required this.viewerCanEndorse,
    required this.endorsedIds,
    required this.onToggleAttended,
    required this.onRemove,
    required this.onEndorse,
    required this.onEditCapacity,
  });

  @override
  Widget build(BuildContext context) {
    final filled = session.attendeeIds.length;
    final max = session.maxPlayers;
    final ratio = max > 0 ? filled / max : 0.0;
    final barColor = ratio >= 1.0
        ? AppColors.errorRed
        : ratio >= 0.8
        ? Colors.orange
        : AppColors.success;
    final attendedCount = attendedIds.length;
    final canEditCapacity = isCoach && !session.isExpired;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_outlined, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                l.attendees,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (isCoach && attendedCount > 0) ...[
                Text(
                  '$attendedCount ${l.attended}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '$filled / $max',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (canEditCapacity)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  splashRadius: 18,
                  tooltip: l.increaseCapacity,
                  onPressed: onEditCapacity,
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.gold,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
              duration: AppMotion.slow,
              curve: AppMotion.enter,
              builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.navyBlue,
                color: barColor,
              ),
            ),
          ),
          if (session.isFull)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l.sessionFull,
                style: const TextStyle(
                  color: AppColors.errorRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // "You have N endorsements left" — shown only when the viewer is
          // actually allowed to endorse (session ended + attended/staff).
          if (viewerCanEndorse)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.thumb_up_outlined,
                    size: 14,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.endorseRemaining((2 - endorsedIds.length).clamp(0, 2)),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          if (session.attendeeIds.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 6),
            ...session.attendeeIds.map((uid) {
              final a = userMap[uid];
              // Profile still loading (or fetch failed) — hold the row's
              // place with a shimmer instead of collapsing the list.
              if (a == null) {
                return PersonRowShimmer(key: ValueKey('att_sk_$uid'));
              }
              final isAttended = attendedIds.contains(uid);
              // You can only endorse someone who actually attended, isn't you,
              // and only if you're eligible (attended too, or staff).
              final canEndorse =
                  viewerCanEndorse && isAttended && uid != viewerUid;
              return _AttendeeItem(
                key: ValueKey('att_$uid'),
                uid: uid,
                name: a.name,
                photoUrl: a.photoUrl,
                attendanceCount: a.attendanceCount,
                injured: a.injured,
                isAttended: isAttended,
                canMark: isCoach,
                canRemove: canManage,
                canViewProfile: true,
                canEndorse: canEndorse,
                alreadyEndorsed: endorsedIds.contains(uid),
                // Once 2 endorsements are used, remaining targets show a
                // disabled button instead of disappearing.
                endorseRemaining: (2 - endorsedIds.length).clamp(0, 2),
                onToggle: onToggleAttended,
                onRemove: onRemove,
                onEndorse: onEndorse,
              );
            }),
          ],

          if (session.hasWaitlist) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.hourglass_bottom,
                  color: AppColors.gold,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  l.waitlist,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${session.waitlistIds.length} / ${session.waitlistSize}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (session.waitlistIds.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...session.waitlistIds.asMap().entries.map((e) {
                final pos = e.key + 1;
                final uid = e.value;
                final u = userMap[uid];
                if (u == null) {
                  return PersonRowShimmer(
                    key: ValueKey('wl_sk_$uid'),
                    avatarRadius: 16,
                    showSubtitle: false,
                  );
                }
                return _WaitlistItem(
                  key: ValueKey('wl_$uid'),
                  uid: uid,
                  position: pos,
                  name: u.name,
                  photoUrl: u.photoUrl,
                  injured: u.injured,
                  canRemove: canManage,
                  canViewProfile: true,
                  onRemove: onRemove,
                );
              }),
            ],
          ],
        ],
      ),
    );
  }
}

class _AttendeeItem extends StatelessWidget {
  final String uid;
  final String name;
  final String photoUrl;
  final int attendanceCount;
  final bool injured;
  final bool isAttended;
  final bool canMark;
  final bool canRemove;
  final bool canViewProfile;
  final bool canEndorse;
  final bool alreadyEndorsed;
  final int endorseRemaining;
  final void Function(String uid, bool attended) onToggle;
  final void Function(String uid, String name) onRemove;
  final void Function(String uid, String name) onEndorse;

  const _AttendeeItem({
    super.key,
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.attendanceCount,
    required this.injured,
    required this.isAttended,
    required this.canMark,
    required this.canRemove,
    required this.canViewProfile,
    required this.canEndorse,
    required this.alreadyEndorsed,
    required this.endorseRemaining,
    required this.onToggle,
    required this.onRemove,
    required this.onEndorse,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();
    final ringColor = isAttended
        ? AppColors.success
        : AppColors.gold.withValues(alpha: 0.4);

    final avatar = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2),
      ),
      child: CircleAvatar(
        radius: 19,
        backgroundColor: AppColors.gold.withValues(alpha: 0.15),
        backgroundImage: photoUrl.isNotEmpty
            ? CachedNetworkImageProvider(photoUrl)
            : null,
        child: photoUrl.isEmpty
            ? Text(
                initials,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              )
            : null,
      ),
    );

    final identity = Row(
      children: [
        avatar,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: canViewProfile ? AppColors.gold : null,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.sports_volleyball,
                    size: 11,
                    color: AppColors.grey,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$attendanceCount ${l.sessionsAttended}',
                    style: const TextStyle(fontSize: 11, color: AppColors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: canViewProfile
                ? InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push(Routes.playerProfile, extra: uid),
                    child: identity,
                  )
                : identity,
          ),
          if (injured) ...[
            const SizedBox(width: 6),
            const InjuredIcon(size: 20),
          ],
          // Show the endorse control only when it's actionable: either the
          // viewer already endorsed this player (filled indicator) or they
          // still have one of their 2 per-session endorsements left. Once both
          // are used, the button disappears for not-yet-endorsed players.
          if (canEndorse && (alreadyEndorsed || endorseRemaining > 0)) ...[
            const SizedBox(width: 6),
            Builder(
              builder: (_) {
                // Endorse allowed only if not already given AND the viewer still
                // has one of their 2 per-session endorsements left.
                final canGive = !alreadyEndorsed && endorseRemaining > 0;
                return IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  splashRadius: 20,
                  tooltip: alreadyEndorsed ? l.endorsed : l.endorse,
                  onPressed: canGive ? () => onEndorse(uid, name) : null,
                  icon: Icon(
                    alreadyEndorsed ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 20,
                    color: alreadyEndorsed ? AppColors.gold : AppColors.grey,
                  ),
                );
              },
            ),
          ],
          if (canMark) ...[
            const SizedBox(width: 6),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              splashRadius: 20,
              tooltip: isAttended ? l.attended : l.notAttended,
              onPressed: () => onToggle(uid, !isAttended),
              icon: Icon(
                isAttended ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 24,
                color: isAttended ? AppColors.success : AppColors.grey,
              ),
            ),
          ],
          if (canRemove) ...[
            const SizedBox(width: 2),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              splashRadius: 20,
              tooltip: l.removePlayer,
              onPressed: () => onRemove(uid, name),
              icon: const Icon(
                Icons.person_remove_outlined,
                size: 20,
                color: AppColors.errorRed,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WaitlistItem extends StatelessWidget {
  final String uid;
  final int position;
  final String name;
  final String photoUrl;
  final bool injured;
  final bool canRemove;
  final bool canViewProfile;
  final void Function(String uid, String name) onRemove;
  const _WaitlistItem({
    super.key,
    required this.uid,
    required this.position,
    required this.name,
    required this.photoUrl,
    required this.injured,
    required this.canRemove,
    required this.canViewProfile,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();
    final identity = Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.gold.withValues(alpha: 0.15),
          backgroundImage: photoUrl.isNotEmpty
              ? CachedNetworkImageProvider(photoUrl)
              : null,
          child: photoUrl.isEmpty
              ? Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: canViewProfile ? AppColors.gold : null,
            ),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$position',
              style: const TextStyle(
                color: AppColors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: canViewProfile
                ? InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push(Routes.playerProfile, extra: uid),
                    child: identity,
                  )
                : identity,
          ),
          if (injured) ...[
            const SizedBox(width: 6),
            const InjuredIcon(size: 18),
          ],
          if (canRemove) ...[
            const SizedBox(width: 2),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 18,
              tooltip: l.removePlayer,
              onPressed: () => onRemove(uid, name),
              icon: const Icon(
                Icons.person_remove_outlined,
                size: 18,
                color: AppColors.errorRed,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  final SessionModel session;
  final bool isJoined;
  final bool isWaitlisted;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final AppLocalizations l;
  const _JoinButton({
    required this.session,
    required this.isJoined,
    required this.isWaitlisted,
    required this.onJoin,
    required this.onLeave,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    if (session.isExpired || session.isOngoing) return const SizedBox.shrink();

    if (isJoined) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: onLeave,
          icon: const Icon(Icons.exit_to_app, color: AppColors.errorRed),
          label: Text(
            l.leaveSession,
            style: const TextStyle(color: AppColors.errorRed),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.errorRed),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (isWaitlisted) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: onLeave,
          icon: const Icon(Icons.hourglass_bottom, color: AppColors.gold),
          label: Text(
            l.leaveWaitlist,
            style: const TextStyle(color: AppColors.gold),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.gold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    // Not a member yet: decide between joining attendees, joining the
    // waitlist, or showing a disabled "full" button.
    final String label;
    final IconData icon;
    final bool canTap;
    if (!session.isFull) {
      label = l.joinSession;
      icon = Icons.sports_volleyball;
      canTap = true;
    } else if (session.hasWaitlist && !session.isWaitlistFull) {
      label = l.joinWaitlist;
      icon = Icons.hourglass_bottom;
      canTap = true;
    } else if (session.hasWaitlist) {
      label = l.waitlistFull;
      icon = Icons.block;
      canTap = false;
    } else {
      label = l.sessionFull;
      icon = Icons.block;
      canTap = false;
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: canTap ? onJoin : null,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _EditCapacityDialog extends StatefulWidget {
  final int currentMax;
  final int currentWaitlist;
  final AppLocalizations l;
  const _EditCapacityDialog({
    required this.currentMax,
    required this.currentWaitlist,
    required this.l,
  });

  @override
  State<_EditCapacityDialog> createState() => _EditCapacityDialogState();
}

class _EditCapacityDialogState extends State<_EditCapacityDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _maxCtrl = TextEditingController(
    text: widget.currentMax.toString(),
  );
  late final TextEditingController _waitCtrl = TextEditingController(
    text: widget.currentWaitlist.toString(),
  );

  @override
  void dispose() {
    _maxCtrl.dispose();
    _waitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return AlertDialog(
      backgroundColor: AppColors.navyLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        l.increaseCapacity,
        style: const TextStyle(color: AppColors.white),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _maxCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                labelText: l.newMaxPlayers,
                labelStyle: const TextStyle(color: AppColors.grey),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.grey),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.gold),
                ),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null) return l.requiredField;
                if (n < widget.currentMax) {
                  return l.mustBeAtLeast(widget.currentMax);
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _waitCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                labelText: l.newWaitlistSize,
                labelStyle: const TextStyle(color: AppColors.grey),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.grey),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.gold),
                ),
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null) return l.requiredField;
                if (n < widget.currentWaitlist) {
                  return l.mustBeAtLeast(widget.currentWaitlist);
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel, style: const TextStyle(color: AppColors.grey)),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(
                context,
              ).pop((int.parse(_maxCtrl.text), int.parse(_waitCtrl.text)));
            }
          },
          child: Text(
            l.changeEmailUpdate,
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatBadgeIcon extends ConsumerStatefulWidget {
  final String sessionId;
  final String tooltip;
  final VoidCallback onTap;
  const _ChatBadgeIcon({
    required this.sessionId,
    required this.tooltip,
    required this.onTap,
  });

  @override
  ConsumerState<_ChatBadgeIcon> createState() => _ChatBadgeIconState();
}

class _ChatBadgeIconState extends ConsumerState<_ChatBadgeIcon> {
  DateTime? _lastSeen;
  bool _loaded = false;

  String get _prefsKey => 'chat_last_seen_${widget.sessionId}';

  @override
  void initState() {
    super.initState();
    _loadLastSeen();
  }

  Future<void> _loadLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_prefsKey);
    if (!mounted) return;
    setState(() {
      _lastSeen = ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
      _loaded = true;
    });
  }

  Future<void> _openChat() async {
    widget.onTap();
    // Wait a beat for the chat route to push, then refresh on return.
    // Re-reading prefs handles the case where SessionChatScreen.dispose()
    // wrote a fresh lastSeen while the user was in the chat.
    await Future.delayed(const Duration(milliseconds: 50));
    await _loadLastSeen();
  }

  @override
  Widget build(BuildContext context) {
    final latestAsync = ref.watch(_latestChatMessageProvider(widget.sessionId));
    bool showDot = false;
    final latest = latestAsync.value;
    if (_loaded && latest != null) {
      if (_lastSeen == null || latest.isAfter(_lastSeen!)) {
        showDot = true;
      }
    }
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: _openChat,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded),
          if (showDot)
            Positioned(
              top: -2,
              right: -2,
              child: Pulse(
                maxScale: 1.35,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.navyBlue, width: 1.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// createdAt of the newest chat message; drives the unread dot.
final _latestChatMessageProvider = StreamProvider.autoDispose
    .family<DateTime?, String>(
      (ref, sessionId) => ref
          .watch(sessionChatRepositoryProvider)
          .watchLatest(sessionId, limit: 1)
          .map((msgs) => msgs.isEmpty ? null : msgs.first.createdAt),
    );
