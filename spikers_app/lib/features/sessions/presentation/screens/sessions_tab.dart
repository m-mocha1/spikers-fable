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
                return SessionsHeader(user: user, sessions: sessions);
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
