import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/coach_summary.dart';
import '../providers/coaches_providers.dart';

class CoachesTab extends ConsumerWidget {
  const CoachesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final coachesAsync = ref.watch(coachesProvider);

    return coachesAsync.when(
      loading: () => const ListShimmer(itemHeight: 112),
      error: (e, _) =>
          ErrorView(onRetry: () => ref.invalidate(coachesProvider)),
      data: (coaches) {
        if (coaches.isEmpty) {
          return EmptyStateView(
              icon: Icons.sports_outlined, title: l.noCoaches);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: coaches.length,
          itemBuilder: (_, i) => AppStaggeredItem(
            index: i,
            child: _CoachCard(coach: coaches[i]),
          ),
        );
      },
    );
  }
}

class _CoachCard extends ConsumerWidget {
  final CoachSummary coach;
  const _CoachCard({required this.coach});

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
    final canDelete = isCoach && coach.uid != myUid;
    final initials = coach.name.trim().isEmpty
        ? '?'
        : coach.name
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.gold.withValues(alpha: 0.2),
              backgroundImage: coach.photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(coach.photoUrl)
                  : null,
              child: coach.photoUrl.isEmpty
                  ? Text(initials,
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 22))
                  : null,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(coach.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 19)),
            ),
            if (canDelete)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.grey),
                color: AppColors.navyLight,
                onSelected: (_) => _confirmDelete(context, ref, l),
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline,
                            color: AppColors.errorRed, size: 20),
                        const SizedBox(width: 10),
                        Text(l.delete,
                            style: const TextStyle(color: AppColors.white)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
