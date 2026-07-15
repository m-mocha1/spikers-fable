import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/core/widgets/floating_nav_bar.dart';
import 'package:spikers_app/core/widgets/session_card.dart';
import 'package:spikers_app/core/widgets/set_profile_basics_dialog.dart';
import '../../domain/entities/session_model.dart';
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
        // The session the header's Next-Up hero spotlights renders in the
        // list as a slim stub instead of a second full card.
        final heroId = user == null
            ? null
            : SessionsHeader.nextUpFor(user, sessions)?.id;
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
            itemCount: sessions.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                if (user == null) return const SizedBox.shrink();
                return SessionsHeader(user: user, sessions: sessions);
              }
              final session = sessions[i - 1];
              return AppStaggeredItem(
                key: ValueKey(session.id),
                index: i - 1,
                child: session.id == heroId
                    ? _SpotlightedEntry(session: session, uid: user!.uid)
                    : SessionCard(session: session),
              );
            },
          ),
        );
      },
    );
  }
}

/// Slim stand-in for the session the Next-Up hero already spotlights: keeps
/// its place in the list (so the UPCOMING count stays honest) without showing
/// the same session as two full cards on one screen.
class _SpotlightedEntry extends StatelessWidget {
  final SessionModel session;
  final String uid;
  const _SpotlightedEntry({required this.session, required this.uid});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final waitlistPos = session.waitlistIds.indexOf(uid);
    final joined = waitlistPos < 0;
    final color = joined ? AppColors.success : AppColors.gold;

    return Pressable(
      onTap: () => context.push(Routes.sessionDetail, extra: session),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(
              joined ? Icons.check_circle : Icons.hourglass_bottom,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              joined ? l.joinedBadge.toUpperCase() : '#${waitlistPos + 1}',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left
                  : Icons.chevron_right,
              size: 18,
              color: AppColors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
