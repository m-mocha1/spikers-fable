import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/core/widgets/floating_nav_bar.dart';
import 'package:spikers_app/core/widgets/session_card.dart';
import 'package:spikers_app/core/widgets/set_profile_basics_dialog.dart';
import '../widgets/sessions_header.dart';
import '../widgets/take_attendance_sheet.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/sessions_providers.dart';

class SessionsTab extends ConsumerWidget {
  const SessionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(upcomingSessionsProvider);

    final l = AppLocalizations.of(context)!;
    return sessionsAsync.when(
      loading: () => const ListShimmer(itemHeight: 154, itemCount: 4),
      error: (e, _) =>
          ErrorView(onRetry: () => ref.invalidate(upcomingSessionsProvider)),
      data: (sessions) {
        final user = ref.watch(currentUserProvider).value;
        if (sessions.isEmpty) {
          if (user != null && !user.isCoach && !user.hasCompleteProfile) {
            return EmptyStateView(
              icon: Icons.badge_outlined,
              title: l.completeProfileForSessions,
              subtitle: l.completeProfileForSessionsDesc,
              action: ElevatedButton.icon(
                onPressed: () => showSetProfileBasicsDialog(context, user),
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.completeProfile),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 48),
                ),
              ),
            );
          }
          if (user != null && !user.isCoach && !user.isPaid) {
            return EmptyStateView(
              icon: Icons.lock_outline,
              title: l.paymentRequired,
              subtitle: l.paymentRequiredDesc,
            );
          }
          return EmptyStateView(
            icon: Icons.sports_volleyball_outlined,
            title: l.noSessions,
            subtitle: l.noSessionsDesc,
          );
        }
        // The session the header's Next-Up hero spotlights is dropped from the
        // list below — showing it again here (even as a stub) just repeats what
        // the hero already says, and rendering its full card would duplicate
        // the art Hero tag the hero owns.
        final heroId = user == null
            ? null
            : SessionsHeader.nextUpFor(user, sessions)?.id;
        final listed = heroId == null
            ? sessions
            : sessions.where((s) => s.id != heroId).toList();
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async {
            ref.invalidate(upcomingSessionsProvider);
            await ref.read(upcomingSessionsProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsetsDirectional.fromSTEB(
              16,
              16,
              16,
              FloatingNavBar.scrollClearance,
            ),
            // +1 for the greeting/spotlight header at index 0.
            itemCount: listed.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                if (user == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (user.isCoach) const _AttendanceTodoBanner(),
                    SessionsHeader(user: user, sessions: sessions),
                  ],
                );
              }
              final session = listed[i - 1];
              return AppStaggeredItem(
                key: ValueKey(session.id),
                index: i - 1,
                child: SessionCard(session: session),
              );
            },
          ),
        );
      },
    );
  }
}

/// Coach-only nudge at the top of the sessions list: when one or more of the
/// coach's sessions have ended without attendance taken, a tappable banner
/// surfaces the count and opens the take-attendance sheet for the most recent
/// one. Complements the once-per-launch [CoachAttendanceGate] popup so the task
/// stays discoverable after the popup is dismissed. Renders nothing when there
/// is nothing outstanding.
class _AttendanceTodoBanner extends ConsumerWidget {
  const _AttendanceTodoBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final todo = ref.watch(coachAttendanceTodoProvider).value ?? const [];
    if (todo.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showTakeAttendanceSheet(
            context,
            session: todo.first,
            onSaved: () => ref.invalidate(coachAttendanceTodoProvider),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.fact_check_outlined,
                    color: AppColors.gold, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.sessionsNeedAttendance(todo.length),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    color: AppColors.gold, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
