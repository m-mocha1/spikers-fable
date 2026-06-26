import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/core/widgets/session_card.dart';
import 'package:spikers_app/core/widgets/set_profile_basics_dialog.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/sessions_providers.dart';

class SessionsTab extends ConsumerWidget {
  const SessionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(upcomingSessionsProvider);

    final l = AppLocalizations.of(context)!;
    return sessionsAsync.when(
      loading: () =>
          const ListShimmer(itemHeight: 140, itemCount: 5),
      error: (e, _) => ErrorView(
          onRetry: () => ref.invalidate(upcomingSessionsProvider)),
      data: (sessions) {
        if (sessions.isEmpty) {
          final user = ref.watch(currentUserProvider).value;
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
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async {
            ref.invalidate(upcomingSessionsProvider);
            await ref.read(upcomingSessionsProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 100),
            itemCount: sessions.length,
            itemBuilder: (_, i) => AppStaggeredItem(
              index: i,
              child: SessionCard(session: sessions[i]),
            ),
          ),
        );
      },
    );
  }

}
