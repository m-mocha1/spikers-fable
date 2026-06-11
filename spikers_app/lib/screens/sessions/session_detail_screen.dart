import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controller/auth_controller.dart';
import '../../controller/session_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/session_model.dart';
import '../../routes/app_routes.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  SessionModel? _session;
  String _sessionId = '';
  StreamSubscription? _sub;
  Map<String, Map<String, String>> _userMap = {};
  List<String> _lastFetchedIds = [];
  List<String> _lastAttendedIds = const [];
  String _coachName = '';
  String _fetchedCoachId = '';
  bool _isArchived = false;
  bool _archiveTriggered = false;
  Timer? _archiveTimer;

  final _auth = Get.find<AuthController>();
  final _ctrl = Get.find<SessionController>();

  @override
  void initState() {
    super.initState();
    final arg = Get.arguments;
    if (arg is SessionModel) {
      _session = arg;
      _sessionId = arg.id;
      _fetchUsers([...arg.attendeeIds, ...arg.waitlistIds]);
      _fetchCoachName(arg.coachId);
    } else if (arg is String) {
      _sessionId = arg;
    }
    if (_sessionId.isEmpty) {
      // No valid session id passed — bail out instead of querying doc('').
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Get.back();
      });
      return;
    }
    _listenToSession();
  }

  void _listenToSession() {
    _sub = FirebaseFirestore.instance
        .collection('sessions')
        .doc(_sessionId)
        .snapshots()
        .listen((doc) async {
      if (!doc.exists) {
        final historyDoc = await FirebaseFirestore.instance
            .collection('sessions_history')
            .doc(_sessionId)
            .get();
        if (historyDoc.exists) {
          _switchToHistory();
          return;
        }
        if (!mounted) return;
        Get.back();
        Get.snackbar('', 'sessionCancelled'.tr,
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      if (!mounted) return;
      final updated = SessionModel.fromDoc(doc);
      setState(() => _session = updated);

      _scheduleArchival(updated);

      final sortedAttended = [...updated.attendedIds]..sort();
      if (!_listsEqual(sortedAttended, _lastAttendedIds)) {
        _lastFetchedIds = const [];
        _lastAttendedIds = sortedAttended;
      }

      _fetchUsers([...updated.attendeeIds, ...updated.waitlistIds]);
      _fetchCoachName(updated.coachId);
    });
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
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('archiveExpiredSessionsNow')
          .call();
    } catch (_) {}
  }

  void _switchToHistory() {
    _sub?.cancel();
    if (!mounted) return;
    setState(() => _isArchived = true);
    _sub = FirebaseFirestore.instance
        .collection('sessions_history')
        .doc(_sessionId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      final updated = SessionModel.fromDoc(doc);
      setState(() => _session = updated);

      final sortedAttended = [...updated.attendedIds]..sort();
      if (!_listsEqual(sortedAttended, _lastAttendedIds)) {
        _lastFetchedIds = const [];
        _lastAttendedIds = sortedAttended;
      }

      _fetchUsers([...updated.attendeeIds, ...updated.waitlistIds]);
      _fetchCoachName(updated.coachId);
    });
  }

  Future<void> _fetchCoachName(String coachId) async {
    if (coachId.isEmpty || coachId == _fetchedCoachId) return;
    _fetchedCoachId = coachId;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users_public')
          .doc(coachId)
          .get();
      if (!mounted) return;
      setState(() {
        _coachName = (doc.data()?['name'] ?? '') as String;
      });
    } catch (_) {
      // Leave _coachName empty; the row will render with a blank value.
    }
  }

  Future<void> _fetchUsers(List<String> ids) async {
    final unique = ids.toSet().toList();
    final sorted = [...unique]..sort();
    if (_listsEqual(sorted, _lastFetchedIds)) return;
    _lastFetchedIds = sorted;

    if (unique.isEmpty) {
      if (mounted) setState(() => _userMap = {});
      return;
    }

    final next = <String, Map<String, String>>{};
    for (var i = 0; i < unique.length; i += 30) {
      final chunk = unique.sublist(i, (i + 30).clamp(0, unique.length));
      final snap = await FirebaseFirestore.instance
          .collection('users_public')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        next[doc.id] = {
          'uid': doc.id,
          'name': (doc.data()['name'] ?? '') as String,
          'gender': (doc.data()['gender'] ?? '') as String,
          'count':
              ((doc.data()['attendanceCount'] ?? 0) as num).toInt().toString(),
          'photoUrl': (doc.data()['photoUrl'] ?? '') as String,
        };
      }
    }
    if (mounted) setState(() => _userMap = next);
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

  Future<void> _confirmCancel(AppLocalizations l) async {
    if (_ctrl.isCancelling.value) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.navyLight,
        title: Text(l.confirmCancelSession),
        content: Text(l.confirmCancelMessage),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false), child: Text(l.no)),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(l.yes,
                style: const TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
    if (confirm == true) _ctrl.cancelSession(_session!.id);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }

    final l = AppLocalizations.of(context)!;
    final uid = _auth.currentUser.value!.uid;
    final isCoach = _auth.isCoach;
    final isOwner = session.coachId == uid;
    final isJoined = session.isJoinedBy(uid);
    final isWaitlisted = session.isWaitlistedBy(uid);
    final canChat = isJoined || isWaitlisted || (isCoach && isOwner);

    return Scaffold(
      appBar: AppBar(
        title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (canChat)
            _ChatBadgeIcon(
              sessionId: session.id,
              tooltip: l.chat,
              onTap: () => Get.toNamed(
                Routes.sessionChat,
                arguments: {'id': session.id, 'title': session.title},
              ),
            ),
          if (isCoach && isOwner && !session.isOngoing && !_isArchived)
            Obx(() {
              final busy = _ctrl.isCancelling.value;
              return TextButton(
                onPressed: busy ? null : () => _confirmCancel(l),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: AppColors.gold,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(l.cancel,
                        style:
                            const TextStyle(color: AppColors.errorRed)),
              );
            }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CountdownCard(session: session, l: l),
            const SizedBox(height: 20),
            _InfoSection(session: session, l: l, coachName: _coachName),
            const SizedBox(height: 20),
            _AttendeesSection(
                session: session,
                l: l,
                userMap: _userMap,
                isCoach: isCoach,
                isOwner: isOwner),
            const SizedBox(height: 30),
            if (!isCoach)
              _JoinButton(
                  session: session,
                  isJoined: isJoined,
                  isWaitlisted: isWaitlisted,
                  ctrl: _ctrl,
                  l: l),
          ],
        ),
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  final SessionModel session;
  final AppLocalizations l;
  const _CountdownCard({required this.session, required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
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
                  : AppColors.grey,
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
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _DetailRow(icon: Icons.person_outline, label: l.coachLabel, value: coachName),
          const Divider(height: 20),
          _DetailRow(icon: Icons.location_on_outlined, label: l.location, value: session.location),
          const Divider(height: 20),
          _DetailRow(icon: Icons.play_arrow_outlined, label: l.startTime, value: fmt.format(session.startTime)),
          const Divider(height: 20),
          _DetailRow(icon: Icons.stop_outlined, label: l.endTime, value: fmt.format(session.endTime)),
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
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.gold),
        const SizedBox(width: 10),
        Text('$label: ',
            style: const TextStyle(color: AppColors.grey, fontSize: 13)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    );
  }
}

class _AttendeesSection extends StatefulWidget {
  final SessionModel session;
  final AppLocalizations l;
  final Map<String, Map<String, String>> userMap;
  final bool isCoach;
  final bool isOwner;
  const _AttendeesSection({
    required this.session,
    required this.l,
    required this.userMap,
    required this.isCoach,
    required this.isOwner,
  });

  @override
  State<_AttendeesSection> createState() => _AttendeesSectionState();
}

class _AttendeesSectionState extends State<_AttendeesSection> {
  SessionModel get session => widget.session;
  AppLocalizations get l => widget.l;
  Map<String, Map<String, String>> get userMap => widget.userMap;
  bool get isCoach => widget.isCoach;
  bool get isOwner => widget.isOwner;

  Future<void> _editCapacity() async {
    final ctrl = Get.find<SessionController>();
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

    final err = await ctrl.updateSessionCapacity(
      session.id,
      newMaxPlayers: newMax == curMax ? null : newMax,
      newWaitlistSize: newWait == curWait ? null : newWait,
    );
    if (err != null) {
      // Defer past the current frame so an in-flight rebuild from the
      // Firestore listener can settle before the snackbar mounts into
      // the Overlay (prevents _dependents.isEmpty teardown races).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar('', err, snackPosition: SnackPosition.BOTTOM);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionController>();
    final filled = session.attendeeIds.length;
    final max = session.maxPlayers;
    final ratio = max > 0 ? filled / max : 0.0;
    final barColor = ratio >= 1.0
        ? AppColors.errorRed
        : ratio >= 0.8
            ? Colors.orange
            : AppColors.success;
    final attendedCount = session.attendedIds.length;
    final canEditCapacity = isOwner && !session.isExpired;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_outlined, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Text(l.attendees,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (isCoach && attendedCount > 0) ...[
                Text('$attendedCount ${l.attended}',
                    style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(width: 8),
              ],
              Text('$filled / $max',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              if (canEditCapacity)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  splashRadius: 18,
                  tooltip: l.increaseCapacity,
                  onPressed: _editCapacity,
                  icon: const Icon(Icons.edit_outlined,
                      color: AppColors.gold, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.navyBlue,
              color: barColor,
            ),
          ),
          if (session.isFull)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l.sessionFull,
                  style: const TextStyle(
                      color: AppColors.errorRed, fontWeight: FontWeight.w600)),
            ),

          if (session.attendeeIds.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 6),
            ...session.attendeeIds.map((uid) {
              final a = userMap[uid];
              if (a == null) return const SizedBox.shrink();
              final isAttended = session.attendedIds.contains(uid);
              return _AttendeeItem(
                key: ValueKey('att_$uid'),
                uid: uid,
                name: a['name'] ?? '',
                gender: a['gender'] ?? '',
                photoUrl: a['photoUrl'] ?? '',
                attendanceCount: int.tryParse(a['count'] ?? '0') ?? 0,
                isAttended: isAttended,
                canMark: isCoach && isOwner,
                onToggle: (u, attended) =>
                    ctrl.markAttended(session.id, u, attended),
              );
            }),
          ],

          if (session.hasWaitlist) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.hourglass_bottom,
                    color: AppColors.gold, size: 18),
                const SizedBox(width: 8),
                Text(l.waitlist,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  '${session.waitlistIds.length} / ${session.waitlistSize}',
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ],
            ),
            if (session.waitlistIds.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...session.waitlistIds.asMap().entries.map((e) {
                final pos = e.key + 1;
                final uid = e.value;
                final u = userMap[uid];
                if (u == null) return const SizedBox.shrink();
                return _WaitlistItem(
                  key: ValueKey('wl_$uid'),
                  position: pos,
                  name: u['name'] ?? '',
                  gender: u['gender'] ?? '',
                  photoUrl: u['photoUrl'] ?? '',
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
  final String gender;
  final String photoUrl;
  final int attendanceCount;
  final bool isAttended;
  final bool canMark;
  final void Function(String uid, bool attended) onToggle;

  const _AttendeeItem({
    super.key,
    required this.uid,
    required this.name,
    required this.gender,
    required this.photoUrl,
    required this.attendanceCount,
    required this.isAttended,
    required this.canMark,
    required this.onToggle,
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
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, color: ringColor),
      child: CircleAvatar(
        radius: 19,
        backgroundColor: isAttended
            ? AppColors.success.withValues(alpha: 0.2)
            : AppColors.gold.withValues(alpha: 0.15),
        backgroundImage: photoUrl.isNotEmpty
            ? CachedNetworkImageProvider(photoUrl)
            : null,
        child: photoUrl.isEmpty
            ? Text(
                initials,
                style: TextStyle(
                    color:
                        isAttended ? AppColors.success : AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              )
            : null,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.sports_volleyball,
                        size: 11, color: AppColors.grey),
                    const SizedBox(width: 3),
                    Text(
                      '$attendanceCount ${l.sessionsAttended}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            gender == 'male' ? Icons.male : Icons.female,
            size: 20,
            color: gender == 'male' ? AppColors.gold : Colors.pinkAccent,
          ),
          if (canMark) ...[
            const SizedBox(width: 6),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
              splashRadius: 20,
              tooltip: isAttended ? l.attended : l.notAttended,
              onPressed: () => onToggle(uid, !isAttended),
              icon: Icon(
                isAttended
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 24,
                color: isAttended ? AppColors.success : AppColors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WaitlistItem extends StatelessWidget {
  final int position;
  final String name;
  final String gender;
  final String photoUrl;
  const _WaitlistItem({
    super.key,
    required this.position,
    required this.name,
    required this.gender,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('#$position',
                style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.gold.withValues(alpha: 0.15),
            backgroundImage: photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(photoUrl)
                : null,
            child: photoUrl.isEmpty
                ? Text(initials,
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 11))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Icon(
            gender == 'male' ? Icons.male : Icons.female,
            size: 18,
            color: gender == 'male' ? AppColors.gold : Colors.pinkAccent,
          ),
        ],
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  final SessionModel session;
  final bool isJoined;
  final bool isWaitlisted;
  final SessionController ctrl;
  final AppLocalizations l;
  const _JoinButton(
      {required this.session,
      required this.isJoined,
      required this.isWaitlisted,
      required this.ctrl,
      required this.l});

  @override
  Widget build(BuildContext context) {
    if (session.isExpired || session.isOngoing) return const SizedBox.shrink();

    return Obx(() {
      final loading = ctrl.isJoining.value;

      if (isJoined) {
        return SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: loading ? null : () => ctrl.leaveSession(session.id),
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.exit_to_app, color: AppColors.errorRed),
            label: Text(l.leaveSession,
                style: const TextStyle(color: AppColors.errorRed)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.errorRed),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
      }

      if (isWaitlisted) {
        return SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: loading ? null : () => ctrl.leaveSession(session.id),
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.hourglass_bottom, color: AppColors.gold),
            label: Text(l.leaveWaitlist,
                style: const TextStyle(color: AppColors.gold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.gold),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
          onPressed: (loading || !canTap)
              ? null
              : () => ctrl.joinSession(session.id),
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.navyBlue))
              : Icon(icon),
          label: Text(label),
        ),
      );
    });
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
  late final TextEditingController _maxCtrl =
      TextEditingController(text: widget.currentMax.toString());
  late final TextEditingController _waitCtrl =
      TextEditingController(text: widget.currentWaitlist.toString());

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
      title: Text(l.increaseCapacity,
          style: const TextStyle(color: AppColors.white)),
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
                    borderSide: BorderSide(color: AppColors.grey)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.gold)),
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
                    borderSide: BorderSide(color: AppColors.grey)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.gold)),
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
          child:
              Text(l.cancel, style: const TextStyle(color: AppColors.grey)),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context)
                  .pop((int.parse(_maxCtrl.text), int.parse(_waitCtrl.text)));
            }
          },
          child: Text(l.changeEmailUpdate,
              style: const TextStyle(
                  color: AppColors.gold, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _ChatBadgeIcon extends StatefulWidget {
  final String sessionId;
  final String tooltip;
  final VoidCallback onTap;
  const _ChatBadgeIcon({
    required this.sessionId,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ChatBadgeIcon> createState() => _ChatBadgeIconState();
}

class _ChatBadgeIconState extends State<_ChatBadgeIcon> {
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
      _lastSeen =
          ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (ctx, snap) {
        bool showDot = false;
        if (_loaded && snap.hasData && snap.data!.docs.isNotEmpty) {
          final ts = snap.data!.docs.first.get('createdAt') as Timestamp?;
          if (ts != null) {
            final latest = ts.toDate();
            if (_lastSeen == null || latest.isAfter(_lastSeen!)) {
              showDot = true;
            }
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
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.navyBlue, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
