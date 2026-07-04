import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_gradients.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/utils/attendance_tiers.dart';
import '../../../../core/utils/endorsement_level.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/level_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/profile_providers.dart';

/// Localized label for an [AttendanceTiers.tierIndex] value. Shared by the
/// games-played card, the milestone celebration snackbar, and any other place
/// that renders a tier name.
String tierLabel(AppLocalizations l, int tier) => switch (tier) {
  4 => l.tierChampion,
  3 => l.tierLegend,
  2 => l.tierVeteran,
  1 => l.tierRegular,
  _ => l.tierRookie,
};

/// Hero "games played" stat with a count-up and a milestone tier badge. Sourced
/// from the target user's public attendance count, so it works for the signed-in
/// user's own profile and for viewing another player. Hidden while loading and
/// for coaches who have no attendance recorded.
class GamesPlayedCard extends ConsumerWidget {
  final String uid;
  final bool isCoach;
  final AppLocalizations l;
  const GamesPlayedCard({
    super.key,
    required this.uid,
    required this.isCoach,
    required this.l,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(myAttendanceCountProvider(uid)).value;
    if (count == null) return const SizedBox.shrink();
    if (isCoach && count == 0) return const SizedBox.shrink();
    // Streak only matters once there's something to streak; 1 week is noise.
    final streak = count > 0
        ? (ref.watch(myStreakProvider(uid)).value ?? 0)
        : 0;

    // Progress toward the next tier boundary; null at Champion (max tier).
    final tier = AttendanceTiers.tierIndex(count);
    final int? nextThreshold = tier < AttendanceTiers.thresholds.length
        ? AttendanceTiers.thresholds[tier]
        : null;
    final prevThreshold = tier == 0 ? 0 : AttendanceTiers.thresholds[tier - 1];

    return AppFadeIn(
      slide: 0.06,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.navyLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.gamesPlayed,
                          style: const TextStyle(
                            color: AppColors.grey,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: count),
                          duration: AppMotion.slow,
                          curve: AppMotion.enter,
                          builder: (_, v, _) => Text(
                            '$v',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (streak >= 2) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                size: 15,
                                color: AppColors.goldAmber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l.weekStreak(streak),
                                style: const TextStyle(
                                  color: AppColors.goldAmber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  LevelBadge(
                    asset: AppAssets.gamesPlayedBadges[tier],
                    size: 96,
                    label: tierLabel(l, tier),
                    // Degrade to the original volleyball medallion if the badge
                    // art can't be loaded, so the card still reads correctly.
                    fallback: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppGradients.goldCta,
                      ),
                      child: const Icon(
                        Icons.sports_volleyball,
                        color: AppColors.navyBlue,
                        size: 22,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: LevelPill(label: tierLabel(l, tier)),
                    ),
                  ),
                ],
              ),
              // Progress toward the next tier — hidden at Champion (max tier).
              if (nextThreshold != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end:
                          (count - prevThreshold) /
                          (nextThreshold - prevThreshold),
                    ),
                    duration: AppMotion.slow,
                    curve: AppMotion.enter,
                    builder: (_, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: AppColors.navyBlue,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$count / $nextThreshold',
                      style: const TextStyle(
                        color: AppColors.grey,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      l.toNextTier(
                        nextThreshold - count,
                        tierLabel(l, tier + 1),
                      ),
                      style: const TextStyle(
                        color: AppColors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact reputation card: lifetime endorsements plus the derived
/// [endorsementLevel] badge. Mirrors the games-played card's styling. Works for
/// the signed-in user's own profile and for viewing another player. Hidden for
/// coaches with none yet.
class EndorsementsCard extends ConsumerWidget {
  final String uid;
  final bool isCoach;
  final AppLocalizations l;
  const EndorsementsCard({
    super.key,
    required this.uid,
    required this.isCoach,
    required this.l,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(myEndorsementCountProvider(uid)).value;
    if (count == null) return const SizedBox.shrink();
    if (isCoach && count == 0) return const SizedBox.shrink();
    final level = endorsementLevel(count);

    return AppFadeIn(
      slide: 0.06,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.navyLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.endorsements,
                      style: const TextStyle(
                        color: AppColors.grey,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: count),
                      duration: AppMotion.slow,
                      curve: AppMotion.enter,
                      builder: (_, v, _) => Text(
                        '$v',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              LevelBadge(
                asset: AppAssets.endorsementBadges[level - 1],
                size: 96,
                label: l.endorsementLevelLabel(level),
                // Degrade to the original thumbs-up medallion if the badge art
                // can't be loaded.
                fallback: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.goldCta,
                  ),
                  child: const Icon(
                    Icons.thumb_up,
                    color: AppColors.navyBlue,
                    size: 22,
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: LevelPill(label: l.endorsementLevelLabel(level)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small gold outlined pill showing a tier/level name.
class LevelPill extends StatelessWidget {
  final String label;
  const LevelPill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
