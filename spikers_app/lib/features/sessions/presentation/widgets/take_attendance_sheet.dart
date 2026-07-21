import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/session_model.dart';
import '../../domain/repositories/sessions_repository.dart';
import '../providers/sessions_providers.dart';

/// Slides up the coach "take attendance" prompt for [session] — a bottom sheet
/// listing every attendee with a present/absent toggle. Everyone starts marked
/// present (the common case), so the coach only unchecks the no-shows and hits
/// confirm. One [SessionsRepository.confirmAttendance] call reconciles the
/// roster and the players' lifetime counts server-side.
///
/// Mirrors [showShoutOutSheet]'s shape. [onSaved] runs after a successful
/// confirm so callers (e.g. the badge banner) can refresh their state.
Future<void> showTakeAttendanceSheet(
  BuildContext context, {
  required SessionModel session,
  VoidCallback? onSaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.navyLight,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _TakeAttendanceSheet(session: session, onSaved: onSaved),
  );
}

class _TakeAttendanceSheet extends ConsumerStatefulWidget {
  const _TakeAttendanceSheet({required this.session, this.onSaved});

  final SessionModel session;
  final VoidCallback? onSaved;

  @override
  ConsumerState<_TakeAttendanceSheet> createState() =>
      _TakeAttendanceSheetState();
}

class _TakeAttendanceSheetState extends ConsumerState<_TakeAttendanceSheet> {
  /// The roster, fixed for the life of the sheet.
  late final List<String> _attendees;

  /// Uids currently marked present. Seeded from any attendance already taken;
  /// otherwise everyone starts present (the coach unchecks the exceptions).
  late final Set<String> _present;

  /// Resolved display profiles, seeded synchronously from the shared cache
  /// (stale-while-revalidate) then refreshed from Firestore.
  Map<String, PublicProfile> _profiles = const {};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _attendees = List<String>.from(widget.session.attendeeIds);
    _present = widget.session.attendedIds.isNotEmpty
        ? widget.session.attendedIds.toSet()
        : _attendees.toSet();
    final repo = ref.read(sessionsRepositoryProvider);
    _profiles = repo.cachedProfiles(_attendees);
    repo.fetchPublicProfilesCached(_attendees).then((fresh) {
      if (mounted) setState(() => _profiles = fresh);
    });
  }

  Future<void> _confirm() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      await ref
          .read(sessionsRepositoryProvider)
          .confirmAttendance(widget.session.id, _present.toList());
      if (!mounted) return;
      showAppSnackbar(l.attendanceSaved);
      widget.onSaved?.call();
      Navigator.of(context).pop();
    } on SessionActionException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackbar(e.code == 'failed-precondition'
          ? l.attendanceNotOpenYet
          : l.unknownError);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackbar(l.unknownError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.takeAttendanceTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.takeAttendanceSubtitle(widget.session.title),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              l.takeAttendanceHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _attendees.length,
                itemBuilder: (context, i) {
                  final uid = _attendees[i];
                  final present = _present.contains(uid);
                  return _AttendeeRow(
                    name: _profiles[uid]?.name ?? '',
                    photoUrl: _profiles[uid]?.photoUrl,
                    present: present,
                    onTap: _saving
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (present) {
                                _present.remove(uid);
                              } else {
                                _present.add(uid);
                              }
                            });
                          },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _confirm,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navyBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.navyBlue,
                      ),
                    )
                  : Text(
                      l.confirmAttendanceButton,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: Text(
                l.takeAttendanceSkip,
                style: const TextStyle(color: AppColors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendeeRow extends StatelessWidget {
  const _AttendeeRow({
    required this.name,
    required this.photoUrl,
    required this.present,
    required this.onTap,
  });

  final String name;
  final String? photoUrl;
  final bool present;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final color = present ? AppColors.success : AppColors.grey;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: AppAvatar(name: name, photoUrl: photoUrl, radius: 22),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: present ? AppColors.white : AppColors.grey,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            present ? Icons.check_circle : Icons.circle_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            present ? l.present : l.absent,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
