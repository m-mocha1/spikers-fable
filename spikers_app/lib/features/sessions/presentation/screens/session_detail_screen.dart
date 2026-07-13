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
import '../../../../core/utils/bidi.dart';
import '../../../../core/utils/title_case.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/app_choice_chips.dart';
import '../../../../core/widgets/branded_text_field.dart';
import '../../../../core/widgets/celebration.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/date_block.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/injured_icon.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../coaches/presentation/providers/coaches_providers.dart';
import '../../domain/repositories/sessions_repository.dart';
import '../providers/sessions_providers.dart';
import '../utils/session_error_l10n.dart';
import '../widgets/member_picker_sheet.dart';

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

  // Roster edit mode (Premium Pass Phase 5): destructive controls (remove
  // player) and capacity editing only appear while the coach has explicitly
  // toggled the roster into its edit state via the header pencil.
  bool _rosterEdit = false;

  // Optimistic overrides for coach attendance toggles (keyed by attendee uid)
  // and peer endorsements — applied the instant the icon is tapped, then
  // reconciled by the live snapshot / endorsements stream.
  final Map<String, bool> _optimisticAttended = {};
  final Set<String> _optimisticEndorsed = {};

  // The pop flight launches from wherever the hero art currently sits. Once
  // the art has scrolled (half) out of view, that would be an offscreen streak
  // down the whole screen — so the flight is disabled until scrolled back up.
  final ScrollController _scrollCtrl = ScrollController();
  bool _heroFlightEnabled = true;

  SessionsRepository get _repo => ref.read(sessionsRepositoryProvider);

  void _onScroll() {
    final enabled = _scrollCtrl.offset < _CountdownCard.height / 2;
    if (enabled != _heroFlightEnabled) {
      setState(() => _heroFlightEnabled = enabled);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
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
    _scrollCtrl.dispose();
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
      // Position they're about to take: current tail of the waitlist + 1.
      showAppSnackbar(
        l.waitlistedSnackPos(session.waitlistIds.length + 1),
      );
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
    } on SessionActionException catch (e) {
      if (mounted) setState(() => _optimistic = null); // roll back the flip
      // failed-precondition = the session started while the screen was open;
      // "something went wrong" would be misleading for a deliberate rule.
      showAppSnackbar(
        e.code == 'failed-precondition'
            ? l.sessionStartedLeaveBlocked
            : l.unknownError,
      );
    } catch (_) {
      if (mounted) setState(() => _optimistic = null);
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

  /// One-tap "mark everyone attended". All checkmarks flip optimistically at
  /// once, but the callables run one at a time: every markAttended is a
  /// transaction on this same session doc, and firing them in parallel can
  /// exhaust their retry budget and silently drop marks.
  Future<void> _markAllAttended(List<String> pending) async {
    if (pending.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      for (final id in pending) {
        _optimisticAttended[id] = true;
      }
    });
    for (final id in pending) {
      await _markAttended(id, true);
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
    final confirm = await showDeleteConfirm(
      context,
      title: l.confirmCancelSession,
      message: l.confirmCancelMessage,
      confirmLabel: l.yes,
      cancelLabel: l.no,
    );
    if (!confirm) return;

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

  Future<void> _makePublic(AppLocalizations l) async {
    final session = _session!;
    final result = await showDialog<(String, int, int)>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _MakePublicDialog(l: l),
    );
    if (!mounted || result == null) return;
    final (gender, minAge, maxAge) = result;

    try {
      await _repo.makeSessionPublic(session.id,
          gender: gender, minAge: minAge, maxAge: maxAge);
      if (!mounted) return;
      showAppSnackbar(l.sessionMadePublic);
    } on SessionActionException catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showAppSnackbar(cancelErrorMessage(l, e.code));
      });
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showAppSnackbar(l.unknownError);
      });
    }
  }

  Future<void> _editMembers(AppLocalizations l) async {
    final session = _session!;
    final picked =
        await showMemberPicker(context, initial: session.memberIds.toSet());
    if (!mounted || picked == null) return;

    // No change — skip the round-trip.
    if (picked.length == session.memberIds.length &&
        picked.containsAll(session.memberIds)) {
      return;
    }
    // Emptying the list would orphan the session; steer the coach to the
    // "make public" action instead (the callable rejects an empty list too).
    if (picked.isEmpty) {
      showAppSnackbar(l.selectMembersError);
      return;
    }

    try {
      await _repo.updateSessionMembers(session.id, picked.toList());
      if (!mounted) return;
      showAppSnackbar(l.membersUpdated);
    } on SessionActionException catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showAppSnackbar(cancelErrorMessage(l, e.code));
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
        ],
      ),
      body: GradientBackground(
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The countdown clock sits on the session art and IS the Hero
              // landing pad — kept OUTSIDE the staggered fade below so the flight
              // lands cleanly. HeroMode kills the pop flight once the art is
              // scrolled away (see [_onScroll]).
              HeroMode(
                enabled: _heroFlightEnabled,
                child: _CountdownCard(session: session, l: l),
              ),
              const SizedBox(height: 18),
              ...[
                    _InfoSection(
                      session: session,
                      l: l,
                      coachName: _coachName,
                      coach: _userMap[session.coachId],
                    ),
                    const SizedBox(height: 18),
                    // Coach controls for a custom (members-only) session:
                    // adjust the member list or open it up to the public.
                    if (isCoach && session.isCustom && !_isArchived) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _editMembers(l),
                              icon: const Icon(Icons.group_outlined,
                                  color: AppColors.gold, size: 18),
                              label: Text(l.editMembers,
                                  style:
                                      const TextStyle(color: AppColors.gold)),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                side: const BorderSide(color: AppColors.gold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _makePublic(l),
                              icon: const Icon(Icons.public,
                                  color: AppColors.gold, size: 18),
                              label: Text(l.makePublic,
                                  style:
                                      const TextStyle(color: AppColors.gold)),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                side: const BorderSide(color: AppColors.gold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],
                    _AttendeesSection(
                      session: session,
                      l: l,
                      userMap: _userMap,
                      attendedIds: attendedIds,
                      isCoach: isCoach,
                      canManage: isCoach,
                      editMode: _rosterEdit,
                      onToggleEditMode: () =>
                          setState(() => _rosterEdit = !_rosterEdit),
                      viewerUid: uid,
                      viewerCanEndorse: viewerCanEndorse,
                      endorsedIds: endorsedIds,
                      onToggleAttended: _markAttended,
                      onRemove: _removeAttendee,
                      onEndorse: _endorse,
                      onEditCapacity: () => _editCapacity(l),
                      onMarkAllAttended: () => _markAllAttended(
                        session.attendeeIds
                            .where((id) => !attendedIds.contains(id))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 26),
                    // Coaches/admins own sessions but may also play in them, so the
                    // Join button is shown to everyone — owners included.
                    _JoinButton(
                      session: session,
                      isJoined: isJoined,
                      isWaitlisted: isWaitlisted,
                      viewerUid: uid,
                      onJoin: () => _join(l),
                      onLeave: () => _leave(l),
                      l: l,
                    ),
                    // Cancelling the whole session is a deliberate, page-level
                    // decision — an explicit red-outline button in the body
                    // (Sign Out style), not an app-bar action that reads as
                    // navigation. Only before kick-off; an ended session is a
                    // celebration, not something to cancel.
                    if (isCoach && session.isUpcoming && !_isArchived) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed:
                            _isCancelling ? null : () => _confirmCancel(l),
                        icon: _isCancelling
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: AppColors.errorRed,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.event_busy_outlined,
                                color: AppColors.errorRed,
                                size: 20,
                              ),
                        label: Text(
                          l.cancelSession,
                          style: const TextStyle(color: AppColors.errorRed),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: const BorderSide(color: AppColors.errorRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
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

/// The hero countdown laid over the session artwork. The art is the Hero
/// landing pad (pure art, so the flight from [SessionCard] stays clean); a
/// status chip sits in the top corner and a segmented flip-clock countdown is
/// centered on the art like a scoreboard. An ambient gloss sweep (matching the
/// Next-Up spotlight) keeps the panel alive without demanding attention.
class _CountdownCard extends StatelessWidget {
  /// Fixed panel height — also the yardstick for when the screen's scroll
  /// position has pushed the hero art far enough away to drop the pop flight.
  static const double height = 190;

  final SessionModel session;
  final AppLocalizations l;
  const _CountdownCard({required this.session, required this.l});

  @override
  Widget build(BuildContext context) {
    final asset = AppAssets
        .cardDesigns[session.designIndex % AppAssets.cardDesigns.length];
    return SizedBox(
      height: height,
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
            // Uniform veil — the list + Next-Up cards keep the brighter art,
            // but the detail hero is dimmed so the centered timer stays legible.
            ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
            // Laminated gloss, same finish as the list cards.
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppGradients.cardSheen),
            ),
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
            // Status chip + countdown — reveals with a fade + pop once the
            // hero art has settled (heroSettle delay).
            Padding(
              padding: const EdgeInsets.all(14),
              child:
                  Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!session.isExpired)
                            _HeroStatusChip(session: session, l: l),
                          Expanded(
                            child: Center(
                              child: session.isExpired
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          l.sessionEnded.toUpperCase(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: AppColors.success,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          l.sessionEndedSubtitle,
                                          style: const TextStyle(
                                            color: AppColors.gold,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          (session.isOngoing
                                                  ? l.endsIn
                                                  : l.startsIn)
                                              .toUpperCase(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: AppColors.gold,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        _SegmentedCountdown(session: session),
                                      ],
                                    ),
                            ),
                          ),
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
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          delay: const Duration(milliseconds: 3200),
          duration: const Duration(milliseconds: 1400),
          angle: 0.6,
          color: AppColors.white.withValues(alpha: 0.08),
        );
  }
}

/// Top-corner state pill on the hero art: a quiet frosted "UPCOMING" tile, or
/// a pulsing green LIVE pill (mirroring the Next-Up spotlight) once ongoing.
class _HeroStatusChip extends StatelessWidget {
  final SessionModel session;
  final AppLocalizations l;
  const _HeroStatusChip({required this.session, required this.l});

  @override
  Widget build(BuildContext context) {
    if (session.isOngoing) {
      return Pulse(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                l.live.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.navyDeep.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 13, color: AppColors.gold),
          const SizedBox(width: 5),
          Text(
            l.upcoming.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scoreboard-style countdown: one translucent tile per time unit (the days
/// tile appears only when needed), each with a small unit caption. The seconds
/// tile only appears inside the final hour — beyond that it's noise, so the
/// clock ticks coarsely (no per-second rebuilds) until the flip-clock finale.
class _SegmentedCountdown extends StatefulWidget {
  final SessionModel session;
  const _SegmentedCountdown({required this.session});

  @override
  State<_SegmentedCountdown> createState() => _SegmentedCountdownState();
}

class _SegmentedCountdownState extends State<_SegmentedCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _remaining() {
    final now = DateTime.now();
    final session = widget.session;
    if (session.isUpcoming) return session.startTime.difference(now);
    if (session.isOngoing) return session.endTime.difference(now);
    return Duration.zero;
  }

  /// One-shot timer rescheduled after every tick, so the cadence adapts:
  /// a lazy 30s while the seconds tile is hidden, 1s once it shows.
  void _schedule() {
    final period = _remaining() > const Duration(hours: 1)
        ? const Duration(seconds: 30)
        : const Duration(seconds: 1);
    _timer = Timer(period, () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    final diff = _remaining();
    final showSeconds = diff <= const Duration(hours: 1);
    final days = diff.inDays;
    final h = (diff.inHours % 24).toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    final l = AppLocalizations.of(context)!;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (days > 0) ...[
            _TimeTile(value: '$days', label: l.unitDays),
            const SizedBox(width: 8),
          ],
          _TimeTile(value: h, label: l.unitHours),
          const SizedBox(width: 8),
          _TimeTile(value: m, label: l.unitMinutes),
          if (showSeconds) ...[
            const SizedBox(width: 8),
            _TimeTile(value: s, label: l.unitSeconds),
          ],
        ],
      ),
    );
  }
}

/// One unit of the segmented countdown — gold digits over a small caption, on
/// the same translucent navy tile as [DateBlock] so the hero reads as one set.
class _TimeTile extends StatelessWidget {
  final String value;
  final String label;
  const _TimeTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.navyDeep.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flip-clock beat: the incoming digit fades in with a small upward
          // slide as the outgoing one drops away.
          ClipRect(
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              switchInCurve: AppMotion.enter,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                value,
                key: ValueKey(value),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared surface for the detail page's panels — the list card's premium
/// treatment (hairline border + layered shadows) on a plain navy body.
BoxDecoration _panelDecoration() => BoxDecoration(
      color: AppColors.navyLight,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.30),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    );

/// Hairline rule used inside the panels instead of full-width [Divider]s.
Widget _hairline() =>
    Container(height: 1, color: AppColors.white.withValues(alpha: 0.08));

/// The "when / where / who" panel. Leads with a ticket date block and the
/// kick-off time in display type, then icon-tile rows (location, coach with
/// their real avatar), and closes with audience pills — so the essentials
/// carry the hierarchy instead of a flat label:value list.
class _InfoSection extends ConsumerWidget {
  final SessionModel session;
  final AppLocalizations l;
  final String coachName;
  final PublicProfile? coach;
  const _InfoSection({
    required this.session,
    required this.l,
    required this.coachName,
    required this.coach,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve the available-coach uids to names via the coaches list (best
    // effort — a name that isn't found yet is simply omitted).
    String? availableCoachNames;
    if (session.coachIds.isNotEmpty) {
      final coaches = ref.watch(coachesProvider).valueOrNull ?? const [];
      final byUid = {for (final c in coaches) c.uid: c.name};
      final names = session.coachIds
          .map((uid) => byUid[uid] ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (names.isNotEmpty) availableCoachNames = names.join(', ');
    }

    final time = DateFormat('HH:mm');
    final duration = session.endTime.difference(session.startTime);
    final durationText = duration.inHours >= 1
        ? l.countdownHoursMinutes(duration.inHours, duration.inMinutes % 60)
        : l.countdownMinutes(duration.inMinutes);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DateBlock(session.startTime, scale: 1.15),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE')
                          .format(session.startTime)
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                        letterSpacing: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${time.format(session.startTime)} – ${time.format(session.endTime)}',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 13, color: AppColors.grey),
                        const SizedBox(width: 4),
                        Text(
                          durationText,
                          style: const TextStyle(
                            color: AppColors.grey,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _hairline(),
          const SizedBox(height: 16),
          _InfoTileRow(
            icon: Icons.location_on_outlined,
            label: l.location,
            value: session.location.toTitleCase(),
          ),
          const SizedBox(height: 14),
          _CoachTileRow(label: l.coachLabel, name: coachName, coach: coach),
          if (availableCoachNames != null) ...[
            const SizedBox(height: 14),
            _InfoTileRow(
              icon: Icons.groups_outlined,
              label: l.availableCoaches,
              value: availableCoachNames,
            ),
          ],
          const SizedBox(height: 16),
          // Audience pills: a custom session ignores gender/age, so it shows
          // the members-only pill instead.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (session.isCustom)
                _AudiencePill(icon: Icons.lock_outline, label: l.membersOnly)
              else ...[
                _AudiencePill(
                  icon: session.gender == 'male'
                      ? Icons.male
                      : session.gender == 'female'
                          ? Icons.female
                          : Icons.people_outline,
                  label: session.gender == 'male'
                      ? l.male
                      : session.gender == 'female'
                          ? l.female
                          : l.genderMixed,
                ),
                _AudiencePill(
                  icon: Icons.cake_outlined,
                  label: l.ageRangeYears(session.minAge, session.maxAge),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Icon-tile detail row: a gold-tinted rounded square, a small-caps caption,
/// and the value in body weight underneath — the caption/value pairing gives
/// the panel its vertical rhythm.
class _InfoTileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: AppColors.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Coach row in the same caption/value rhythm as [_InfoTileRow], but led by
/// the coach's actual avatar (initials while the profile is still loading).
class _CoachTileRow extends StatelessWidget {
  final String label;
  final String name;
  final PublicProfile? coach;
  const _CoachTileRow({
    required this.label,
    required this.name,
    required this.coach,
  });

  @override
  Widget build(BuildContext context) {
    final display = name.isNotEmpty ? name : (coach?.name ?? '');
    final photoUrl = coach?.photoUrl ?? '';
    final initials = display.trim().isEmpty
        ? '?'
        : display
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 2),
          ),
          child: CircleAvatar(
            radius: 17,
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
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                display,
                style:
                    const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small gold-tinted audience tag (gender / age range / members-only).
class _AudiencePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _AudiencePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.gold,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
  final bool editMode;
  final VoidCallback onToggleEditMode;
  final String viewerUid;
  final bool viewerCanEndorse;
  final Set<String> endorsedIds;
  final void Function(String uid, bool attended) onToggleAttended;
  final void Function(String uid, String name) onRemove;
  final void Function(String uid, String name) onEndorse;
  final VoidCallback onEditCapacity;
  final VoidCallback onMarkAllAttended;
  const _AttendeesSection({
    required this.session,
    required this.l,
    required this.userMap,
    required this.attendedIds,
    required this.isCoach,
    required this.canManage,
    required this.editMode,
    required this.onToggleEditMode,
    required this.viewerUid,
    required this.viewerCanEndorse,
    required this.endorsedIds,
    required this.onToggleAttended,
    required this.onRemove,
    required this.onEndorse,
    required this.onEditCapacity,
    required this.onMarkAllAttended,
  });

  @override
  Widget build(BuildContext context) {
    final filled = session.attendeeIds.length;
    final max = session.maxPlayers;
    final ratio = max > 0 ? filled / max : 0.0;
    final isEnded = session.isExpired;
    // A finished session is a result, not an alarm: the meter turns success
    // green regardless of how full it got. Live/upcoming keeps the
    // traffic-light readout.
    final barColor = isEnded
        ? AppColors.success
        : ratio >= 1.0
        ? AppColors.errorRed
        : ratio >= 0.8
        ? Colors.orange
        : AppColors.success;
    final attendedCount = attendedIds.length;
    // Courtside attendance stays one tap away while the session is live or
    // upcoming; once it has ended the per-row toggles retreat behind edit
    // mode (corrections stay possible — markAttended works on history).
    final showMarkControls = isCoach && (!isEnded || editMode);
    final showMarkAll = showMarkControls &&
        session.attendeeIds.isNotEmpty &&
        attendedCount < session.attendeeIds.length;
    // Destructive controls only ever exist in edit mode, and never on a
    // session that already happened.
    final showRemove = canManage && editMode && !isEnded;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.group_outlined,
                  size: 19,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.attendees,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                    // Endorsement budget lives with the roster header it
                    // applies to, instead of floating under the meter.
                    if (viewerCanEndorse)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          l.endorseRemaining(
                            (2 - endorsedIds.length).clamp(0, 2),
                          ),
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Edit mode surfaces capacity editing (live sessions); the
              // normal courtside state — and ended-session edit mode, where
              // capacity no longer applies — offers the labeled one-tap
              // "Mark all" shortcut instead of the old unlabeled double-check.
              if (editMode && isCoach && !isEnded) ...[
                const SizedBox(width: 6),
                AppChoiceChip(
                  label: l.editCapacity,
                  icon: Icons.tune,
                  selected: false,
                  onTap: onEditCapacity,
                ),
              ] else if (showMarkAll && (!editMode || isEnded)) ...[
                const SizedBox(width: 6),
                AppChoiceChip(
                  label: l.markAll,
                  icon: Icons.done_all,
                  selected: false,
                  onTap: onMarkAllAttended,
                ),
              ],
              if (isCoach) ...[
                const SizedBox(width: 2),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  splashRadius: 18,
                  tooltip: editMode ? l.done : l.editRoster,
                  onPressed: onToggleEditMode,
                  icon: Icon(
                    editMode ? Icons.done : Icons.edit_outlined,
                    color: AppColors.gold,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Roster at a glance: big filled-count against capacity, with the
          // attendance tally (coach) and the spots-left state as quiet pills.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$filled',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Text(
                ' / $max',
                style: const TextStyle(
                  color: AppColors.grey,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (isCoach && attendedCount > 0) ...[
                _StatPill(
                  icon: Icons.check,
                  label: l.attendedCount(attendedCount),
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
              ],
              // Urgency pills only make sense while joining is still possible;
              // an ended session hides "Session Full" instead of alarming.
              if (!isEnded)
                _StatPill(
                  icon: session.isFull
                      ? Icons.block
                      : Icons.local_fire_department_outlined,
                  label: session.isFull
                      ? l.sessionFull
                      : l.spotsLeft(session.spotsLeft),
                  color: barColor,
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Capacity meter — the same treatment as the list card's bottom
          // edge, restating the pill colour as *how full*.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
            duration: AppMotion.slow,
            curve: AppMotion.enter,
            builder: (_, value, _) => Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.navyBlue,
                borderRadius: BorderRadius.circular(3),
              ),
              alignment: AlignmentDirectional.centerStart,
              child: value <= 0
                  ? const SizedBox.shrink()
                  : FractionallySizedBox(
                      widthFactor: value,
                      heightFactor: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
            ),
          ),

          if (session.attendeeIds.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...session.attendeeIds.map((uid) {
              final a = userMap[uid];
              // Profile still loading (or fetch failed) — hold the row's
              // place with a shimmer instead of collapsing the list.
              if (a == null) {
                return _PersonTile(
                  key: ValueKey('att_sk_$uid'),
                  child: const PersonRowShimmer(),
                );
              }
              final isAttended = attendedIds.contains(uid);
              // You can only endorse someone who actually attended, isn't you,
              // and only if you're eligible (attended too, or staff). Edit
              // mode swaps the celebration controls out for admin ones.
              final canEndorse = viewerCanEndorse &&
                  isAttended &&
                  uid != viewerUid &&
                  !editMode;
              return _AttendeeItem(
                key: ValueKey('att_$uid'),
                uid: uid,
                name: a.name,
                photoUrl: a.photoUrl,
                attendanceCount: a.attendanceCount,
                injured: a.injured,
                isAttended: isAttended,
                isViewer: uid == viewerUid,
                canMark: showMarkControls,
                canRemove: showRemove,
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
            const SizedBox(height: 8),
            _hairline(),
            const SizedBox(height: 14),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '${session.waitlistIds.length} / ${session.waitlistSize}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            if (session.waitlistIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...session.waitlistIds.asMap().entries.map((e) {
                final pos = e.key + 1;
                final uid = e.value;
                final u = userMap[uid];
                if (u == null) {
                  return _PersonTile(
                    key: ValueKey('wl_sk_$uid'),
                    child: const PersonRowShimmer(
                      avatarRadius: 16,
                      showSubtitle: false,
                    ),
                  );
                }
                return _WaitlistItem(
                  key: ValueKey('wl_$uid'),
                  uid: uid,
                  position: pos,
                  name: u.name,
                  photoUrl: u.photoUrl,
                  injured: u.injured,
                  canRemove: showRemove,
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

/// Small tinted status pill used in the roster stats row.
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared surface for one person in the roster — a quiet inset tile so each
/// player reads as their own card inside the panel.
class _PersonTile extends StatelessWidget {
  final Widget child;
  const _PersonTile({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.navyBlue.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: child,
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
  final bool isViewer;
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
    required this.isViewer,
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

    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        // The ring recolours with a quick cross-fade when attendance flips.
        AnimatedContainer(
          duration: AppMotion.fast,
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
        ),
        // Checked-in badge, popping in the moment the coach marks them.
        if (isAttended)
          PositionedDirectional(
            end: -2,
            bottom: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.navyLight, width: 2),
              ),
              child: const Icon(
                Icons.check,
                size: 9,
                color: AppColors.white,
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: AppMotion.fast,
                  curve: Curves.easeOutBack,
                ),
          ),
      ],
    );

    final identity = Row(
      children: [
        avatar,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      bidiIsolate(name),
                      // Two lines before ellipsis — long names share the row
                      // with up to three trailing action icons.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: canViewProfile ? AppColors.gold : null,
                      ),
                    ),
                  ),
                  if (isViewer) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l.youLabel.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
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
                    l.sessionsAttended(attendanceCount),
                    style: const TextStyle(fontSize: 11, color: AppColors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return _PersonTile(
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
              // Outlined check (not a bare circle) so the idle state reads as
              // "tap to check in", not a radio button.
              icon: Icon(
                isAttended ? Icons.check_circle : Icons.check_circle_outline,
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
            bidiIsolate(name),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: canViewProfile ? AppColors.gold : null,
            ),
          ),
        ),
      ],
    );
    return _PersonTile(
      child: Row(
        children: [
          // Queue position as a numbered dot, styled like the facepile so the
          // waitlist reads as "next in line" rather than a plain list.
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Text(
                  '$position',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
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
  final String viewerUid;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final AppLocalizations l;
  const _JoinButton({
    required this.session,
    required this.isJoined,
    required this.isWaitlisted,
    required this.viewerUid,
    required this.onJoin,
    required this.onLeave,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    if (session.isExpired || session.isOngoing) return const SizedBox.shrink();

    if (isJoined) {
      return _ActionShell(
        onTap: onLeave,
        fill: AppColors.errorRed.withValues(alpha: 0.08),
        borderColor: AppColors.errorRed,
        child: _actionRow(
          Icons.exit_to_app,
          l.leaveSession,
          AppColors.errorRed,
        ),
      );
    }

    if (isWaitlisted) {
      // The viewer's live queue position. An optimistic (just-tapped) join
      // isn't in waitlistIds yet — they're about to take the tail spot.
      final idx = session.waitlistIds.indexOf(viewerUid);
      final position = idx >= 0 ? idx + 1 : session.waitlistIds.length + 1;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.hourglass_bottom,
                  size: 14,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l.waitlistStanding(position),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _ActionShell(
            onTap: onLeave,
            fill: AppColors.gold.withValues(alpha: 0.08),
            borderColor: AppColors.gold,
            child: _actionRow(
              Icons.hourglass_bottom,
              l.leaveWaitlist,
              AppColors.gold,
            ),
          ),
        ],
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

    if (!canTap) {
      return _ActionShell(
        onTap: null,
        fill: AppColors.white.withValues(alpha: 0.06),
        borderColor: AppColors.white.withValues(alpha: 0.10),
        child: _actionRow(icon, label, AppColors.grey),
      );
    }

    // The one action the screen builds toward — a glowing gold gradient bar.
    return Pressable(
      onTap: onJoin,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppGradients.goldCta,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.30),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.navyBlue),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.navyBlue,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionRow(IconData icon, String label, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Secondary action bar (leave / disabled states) sharing the CTA's geometry
/// so the button area never shifts as membership changes.
class _ActionShell extends StatelessWidget {
  final VoidCallback? onTap;
  final Color fill;
  final Color borderColor;
  final Widget child;
  const _ActionShell({
    required this.onTap,
    required this.fill,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.4),
        ),
        child: child,
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
            BrandedTextField(
              label: l.newMaxPlayers,
              controller: _maxCtrl,
              keyboardType: TextInputType.number,
              // The dialog surface is navyLight — use the darker navy fill
              // so the fields stay visible.
              fillColor: AppColors.navyBlue,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null) return l.requiredField;
                if (n < widget.currentMax) {
                  return l.mustBeAtLeast(widget.currentMax);
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            BrandedTextField(
              label: l.newWaitlistSize,
              controller: _waitCtrl,
              keyboardType: TextInputType.number,
              fillColor: AppColors.navyBlue,
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

/// Dialog shown when a coach converts a custom session to public: pick the
/// gender + age audience it should open to. Returns (gender, minAge, maxAge).
class _MakePublicDialog extends StatefulWidget {
  final AppLocalizations l;
  const _MakePublicDialog({required this.l});

  @override
  State<_MakePublicDialog> createState() => _MakePublicDialogState();
}

class _MakePublicDialogState extends State<_MakePublicDialog> {
  final _formKey = GlobalKey<FormState>();
  String _gender = 'mixed';
  final _minCtrl = TextEditingController(text: '16');
  final _maxCtrl = TextEditingController(text: '40');

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  String? _validateAge(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null || n < 0 || n > 120) return widget.l.requiredField;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return AlertDialog(
      backgroundColor: AppColors.navyLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l.makePublic, style: const TextStyle(color: AppColors.white)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.makePublicSubtitle,
                style: const TextStyle(color: AppColors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            AppChoiceChips<String>(
              value: _gender,
              expanded: true,
              // The dialog surface is navyLight — use the darker navy fill
              // so the idle chips stay visible (same as the fields below).
              fillColor: AppColors.navyBlue,
              onSelected: (v) => setState(() => _gender = v),
              options: [
                AppChoiceChipOption(value: 'male', label: l.male),
                AppChoiceChipOption(value: 'female', label: l.female),
                AppChoiceChipOption(value: 'mixed', label: l.genderMixed),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: BrandedTextField(
                    label: l.minAge,
                    controller: _minCtrl,
                    keyboardType: TextInputType.number,
                    // The dialog surface is navyLight — use the darker navy
                    // fill so the fields stay visible.
                    fillColor: AppColors.navyBlue,
                    validator: _validateAge,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: BrandedTextField(
                    label: l.maxAge,
                    controller: _maxCtrl,
                    keyboardType: TextInputType.number,
                    fillColor: AppColors.navyBlue,
                    validator: _validateAge,
                  ),
                ),
              ],
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
            if (!_formKey.currentState!.validate()) return;
            final minAge = int.parse(_minCtrl.text);
            final maxAge = int.parse(_maxCtrl.text);
            if (minAge > maxAge) {
              showAppSnackbar(l.invalidAgeRange);
              return;
            }
            Navigator.of(context).pop((_gender, minAge, maxAge));
          },
          child: Text(l.makePublic,
              style: const TextStyle(
                  color: AppColors.gold, fontWeight: FontWeight.w700)),
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
