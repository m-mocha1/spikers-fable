import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/celebration.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/session_model.dart';
import '../../domain/repositories/sessions_repository.dart';
import '../providers/sessions_providers.dart';

/// Per-session endorsement budget, mirroring the server cap in
/// `endorsePlayer` (`MAX_ENDORSEMENTS_PER_SESSION`) and the session-detail
/// roster. The prompt lets the user spend up to this many in one sitting.
const _maxEndorsements = 2;

/// Slides up the post-session "shout-out" prompt for [session] — a dismissible
/// bottom sheet listing the teammates who attended, each with a thumb-up. It
/// reuses the existing `endorse()` path verbatim; the trigger (once per app
/// launch, only for recently-ended attended sessions) lives in `ShoutOutGate`.
Future<void> showShoutOutSheet(
  BuildContext context, {
  required SessionModel session,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.navyLight,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ShoutOutSheet(session: session),
  );
}

class _ShoutOutSheet extends ConsumerStatefulWidget {
  const _ShoutOutSheet({required this.session});

  final SessionModel session;

  @override
  ConsumerState<_ShoutOutSheet> createState() => _ShoutOutSheetState();
}

class _ShoutOutSheetState extends ConsumerState<_ShoutOutSheet> {
  /// The other attendees (session roster minus the signed-in user), fixed for
  /// the life of the sheet.
  late final List<String> _others;

  /// Resolved display profiles, seeded synchronously from the shared cache
  /// (stale-while-revalidate) then refreshed from Firestore.
  Map<String, PublicProfile> _profiles = const {};

  /// Targets endorsed during this sheet, added optimistically so the row flips
  /// the instant they tap — the write is idempotent and the stream confirms it.
  final Set<String> _optimistic = {};

  @override
  void initState() {
    super.initState();
    final uid = ref.read(currentUserProvider).value?.uid;
    _others = widget.session.attendedIds.where((id) => id != uid).toList();
    final repo = ref.read(sessionsRepositoryProvider);
    _profiles = repo.cachedProfiles(_others);
    repo.fetchPublicProfilesCached(_others).then((fresh) {
      if (mounted) setState(() => _profiles = fresh);
    });
  }

  Future<void> _endorse(String userId, String name) async {
    final l = AppLocalizations.of(context)!;
    setState(() => _optimistic.add(userId));
    HapticFeedback.lightImpact();
    if (mounted) showCelebration(context, dim: true);
    showAppSnackbar(l.endorsedPlayer(name));
    try {
      await ref.read(sessionsRepositoryProvider).endorse(
            widget.session.id,
            userId,
          );
    } on SessionActionException catch (_) {
      // e.g. the session isn't marked ended yet, or the per-session cap — the
      // UI already gates these, so this is a defensive undo.
      if (mounted) setState(() => _optimistic.remove(userId));
      showAppSnackbar(l.endorseFailed);
    } catch (_) {
      if (mounted) setState(() => _optimistic.remove(userId));
      showAppSnackbar(l.unknownError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Server-confirmed endorsements for this session, unioned with the ones
    // added optimistically in this sheet.
    final confirmed =
        ref.watch(myEndorsementsProvider(widget.session.id)).value ??
            const <String>{};
    final endorsed = {...confirmed, ..._optimistic};
    final remaining = (_maxEndorsements - endorsed.length).clamp(0, _maxEndorsements);

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
              l.shoutOutTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.shoutOutSubtitle(widget.session.title),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              l.endorseRemaining(remaining),
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
                itemCount: _others.length,
                itemBuilder: (context, i) {
                  final uid = _others[i];
                  final name = _profiles[uid]?.name ?? '';
                  final alreadyEndorsed = endorsed.contains(uid);
                  final canGive = !alreadyEndorsed && remaining > 0;
                  return _AttendeeRow(
                    name: name,
                    photoUrl: _profiles[uid]?.photoUrl,
                    endorsed: alreadyEndorsed,
                    canGive: canGive,
                    onEndorse: () => _endorse(uid, name),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l.shoutOutSkip,
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
    required this.endorsed,
    required this.canGive,
    required this.onEndorse,
  });

  final String name;
  final String? photoUrl;
  final bool endorsed;
  final bool canGive;
  final VoidCallback onEndorse;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppAvatar(name: name, photoUrl: photoUrl, radius: 22),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: endorsed
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.thumb_up, color: AppColors.gold, size: 20),
                const SizedBox(width: 6),
                Text(
                  l.endorsed,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : TextButton.icon(
              onPressed: canGive ? onEndorse : null,
              icon: Icon(
                Icons.thumb_up_outlined,
                size: 18,
                color: canGive ? AppColors.gold : AppColors.grey,
              ),
              label: Text(
                l.endorse,
                style: TextStyle(
                  color: canGive ? AppColors.gold : AppColors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }
}
