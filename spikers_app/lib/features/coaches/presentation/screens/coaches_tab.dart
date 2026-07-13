import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../players/presentation/widgets/player_card.dart';
import '../../domain/entities/coach_summary.dart';
import '../providers/coaches_providers.dart';

class CoachesTab extends ConsumerWidget {
  const CoachesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final coachesAsync = ref.watch(coachesProvider);

    return coachesAsync.when(
      loading: () => const ListShimmer(itemHeight: 76),
      error: (e, _) =>
          ErrorView(onRetry: () => ref.invalidate(coachesProvider)),
      data: (coaches) {
        if (coaches.isEmpty) {
          return EmptyStateView(
              icon: Icons.sports_outlined, title: l.noCoaches);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          // +1 for the count header at index 0.
          itemCount: coaches.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              // Quiet count line, matching the header discipline of the
              // players list.
              return Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.xs,
                  bottom: AppSpacing.md,
                ),
                child: Text(
                  l.coachesCount(coaches.length).toUpperCase(),
                  style: AppTextStyles.sectionHeader,
                ),
              );
            }
            final coach = coaches[i - 1];
            return AppStaggeredItem(
              key: ValueKey(coach.uid),
              index: i - 1,
              child: _CoachCard(coach: coach),
            );
          },
        );
      },
    );
  }
}

/// Coach row on the shared [PlayerCard] silhouette — same card, avatar ring
/// and name-first hierarchy as the players list, with a quiet COACH eyebrow
/// instead of the attendance story (`CoachSummary` carries no attendance
/// data). The whole row opens the viewer-aware profile; the staff-only menu
/// leads with that same non-destructive action so deletion is never the only
/// item.
class _CoachCard extends ConsumerWidget {
  final CoachSummary coach;
  const _CoachCard({required this.coach});

  void _openProfile(BuildContext context) =>
      context.push(Routes.playerProfile, extra: coach.uid);

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final confirmed = await showDeleteConfirm(
      context,
      title: l.deleteAccountTitle,
      message: l.deleteAccountConfirm(coach.name),
      confirmLabel: l.delete,
      cancelLabel: l.cancel,
    );
    if (!confirmed) return;
    try {
      await ref.read(coachesRepositoryProvider).deleteCoach(coach.uid);
      showAppSnackbar(l.accountDeleted);
    } catch (_) {
      showAppSnackbar(l.unknownError);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final isCoach = ref.watch(isCoachProvider);
    final myUid = ref.watch(currentUserProvider).value?.uid;
    // Staff manage coach accounts, but nobody may delete their own account
    // (mirrors the server-side guard). Players see no menu at all.
    final canDelete = isCoach && coach.uid != myUid;

    return PlayerCard(
      name: coach.name,
      photoUrl: coach.photoUrl,
      roleLabel: l.coachLabel,
      onTap: () => _openProfile(context),
      trailing: canDelete
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.grey),
              color: AppColors.navyLight,
              onSelected: (action) => switch (action) {
                'profile' => _openProfile(context),
                _ => _confirmDelete(context, ref, l),
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          color: AppColors.grey, size: 20),
                      const SizedBox(width: AppSpacing.sm + 2),
                      Text(l.viewProfile,
                          style: const TextStyle(color: AppColors.white)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline,
                          color: AppColors.errorRed, size: 20),
                      const SizedBox(width: AppSpacing.sm + 2),
                      Text(l.delete,
                          style: const TextStyle(color: AppColors.white)),
                    ],
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
