import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/coach_summary.dart';
import '../providers/coaches_providers.dart';

class CoachesTab extends ConsumerWidget {
  const CoachesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final coachesAsync = ref.watch(coachesProvider);

    return coachesAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, _) => Center(
        child: Text(l.errorOccurred,
            style: const TextStyle(color: AppColors.grey, fontSize: 15)),
      ),
      data: (coaches) {
        if (coaches.isEmpty) {
          return Center(
            child: Text(l.noCoaches,
                style: const TextStyle(color: AppColors.grey, fontSize: 15)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: coaches.length,
          itemBuilder: (_, i) => _CoachCard(coach: coaches[i]),
        );
      },
    );
  }
}

class _CoachCard extends StatelessWidget {
  final CoachSummary coach;
  const _CoachCard({required this.coach});

  @override
  Widget build(BuildContext context) {
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
          ],
        ),
      ),
    );
  }
}
