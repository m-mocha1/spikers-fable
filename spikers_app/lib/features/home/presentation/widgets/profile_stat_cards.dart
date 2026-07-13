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

/// Shared chrome for the profile's stat cards — same radius/border/shadow as
/// the roster's [PlayerCard], so the whole app reads as one card family.
/// The progression hero card passes a gold [borderColor] to sit above its
/// siblings in the hierarchy.
BoxDecoration profileCardChrome({Color? borderColor}) => BoxDecoration(
  color: AppColors.navyLight,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(
    color: borderColor ?? AppColors.white.withValues(alpha: 0.07),
  ),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ],
);

/// Hero progression card: games-played count with a season-pass-style
/// milestone track walking through all five tiers. Sourced from the target
/// user's public attendance count, so it works for the signed-in user's own
/// profile and for viewing another player. Hidden while loading and for
/// coaches who have no attendance recorded.
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

    return AppFadeIn(
      slide: 0.06,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: profileCardChrome(
            borderColor: AppColors.gold.withValues(alpha: 0.35),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  LevelBadge(
                    asset: AppAssets.gamesPlayedBadges[tier],
                    size: 72,
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.gamesPlayed.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
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
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      LevelPill(label: tierLabel(l, tier)),
                      if (streak >= 2) ...[
                        const SizedBox(height: 8),
                        _StreakChip(streak: streak, l: l),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MilestoneTrack(count: count, l: l),
              const SizedBox(height: 10),
              if (nextThreshold != null)
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
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 14,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      l.topTierReached,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Season-pass-style milestone track: a gradient fill sweeping across five
/// evenly spaced tier nodes ([AttendanceTiers] boundaries). Nodes light up as
/// the animated fill passes them. Every node is the same small tick dot — no
/// enlarged, glowing "thumb" — so the track reads as progress, not a slider
/// (Premium Pass Phase 6). Threshold counts sit under each node so the whole
/// ladder is visible at a glance. Directional throughout, so it mirrors
/// correctly in RTL.
class _MilestoneTrack extends StatelessWidget {
  final int count;
  final AppLocalizations l;
  const _MilestoneTrack({required this.count, required this.l});

  static const _trackTop = 6.0;
  static const _trackHeight = 6.0;

  @override
  Widget build(BuildContext context) {
    final nodes = <int>[0, ...AttendanceTiers.thresholds];
    final segments = nodes.length - 1;
    final tier = AttendanceTiers.tierIndex(count);

    // Overall fill fraction: completed segments plus progress within the
    // current one, on an evenly spaced track (season-pass convention).
    final double target;
    if (tier >= segments) {
      target = 1;
    } else {
      final lo = nodes[tier];
      final hi = nodes[tier + 1];
      target = (tier + ((count - lo) / (hi - lo)).clamp(0.0, 1.0)) / segments;
    }
    const trackCenter = _trackTop + _trackHeight / 2;

    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: target),
            duration: AppMotion.slow,
            curve: AppMotion.enter,
            builder: (context, value, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Base track.
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    top: _trackTop,
                    child: Container(
                      height: _trackHeight,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  // Animated gradient fill.
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    top: _trackTop,
                    child: SizedBox(
                      height: _trackHeight,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FractionallySizedBox(
                          widthFactor: value.clamp(0.0, 1.0),
                          heightFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppGradients.goldCta,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Tier nodes + threshold labels. A node counts as reached
                  // once the sweeping fill has passed it, so they light up in
                  // rhythm with the animation.
                  for (var i = 0; i < nodes.length; i++) ...[
                    _node(
                      position: width * i / segments,
                      reached: value * segments + 1e-6 >= i,
                      trackCenter: trackCenter,
                    ),
                    PositionedDirectional(
                      start: width * i / segments - 20,
                      top: _trackTop + _trackHeight + 9,
                      child: SizedBox(
                        width: 40,
                        child: Text(
                          '${nodes[i]}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i <= tier
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: i <= tier
                                ? AppColors.gold
                                : AppColors.white.withValues(alpha: 0.60),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  // Uniform tick dot — same size whether reached or current, and no glow, so
  // nothing on the track reads as a draggable thumb.
  Widget _node({
    required double position,
    required bool reached,
    required double trackCenter,
  }) {
    const size = 12.0;
    return PositionedDirectional(
      start: position - size / 2,
      top: trackCenter - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: reached ? AppGradients.goldCta : null,
          color: reached ? null : AppColors.navyBlue,
          border: Border.all(
            color: reached
                ? AppColors.navyLight
                : AppColors.white.withValues(alpha: 0.18),
            width: reached ? 2 : 1.5,
          ),
        ),
      ),
    );
  }
}

/// Small amber chip for the weekly attendance streak — kept quiet so it reads
/// as a bonus, not a nag.
class _StreakChip extends StatelessWidget {
  final int streak;
  final AppLocalizations l;
  const _StreakChip({required this.streak, required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.goldAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department,
            size: 13,
            color: AppColors.goldAmber,
          ),
          const SizedBox(width: 4),
          Text(
            l.weekStreak(streak),
            style: const TextStyle(
              color: AppColors.goldAmber,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reputation card: lifetime endorsements, the derived [endorsementLevel]
/// badge, and a progress bar toward the next level ([endorsementThresholds]).
/// Mirrors the games-played card's styling one step down the hierarchy. Works
/// for the signed-in user's own profile and for viewing another player.
/// Hidden for coaches with none yet.
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

    // Progress within the current level; next is null at level 5 (max).
    final int? next = level < 5 ? endorsementThresholds[level - 1] : null;
    final prev = level == 1 ? 0 : endorsementThresholds[level - 2];
    final ratio = next == null
        ? 1.0
        : ((count - prev) / (next - prev)).clamp(0.0, 1.0);

    return AppFadeIn(
      slide: 0.06,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: profileCardChrome(),
          child: Column(
            children: [
              Row(
                children: [
                  LevelBadge(
                    asset: AppAssets.endorsementBadges[level - 1],
                    size: 60,
                    label: l.endorsementLevelLabel(level),
                    // Degrade to the original thumbs-up medallion if the badge
                    // art can't be loaded.
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.endorsements.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
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
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  LevelPill(label: l.endorsementLevelLabel(level)),
                ],
              ),
              const SizedBox(height: 14),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: AppMotion.slow,
                curve: AppMotion.enter,
                builder: (context, value, _) => Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  child: value <= 0
                      ? const SizedBox.shrink()
                      : FractionallySizedBox(
                          widthFactor: value,
                          heightFactor: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: AppGradients.goldCta,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              if (next != null)
                Row(
                  children: [
                    Text(
                      '$count / $next',
                      style: const TextStyle(
                        color: AppColors.grey,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      l.toNextTier(
                        next - count,
                        l.endorsementLevelLabel(level + 1),
                      ),
                      style: const TextStyle(
                        color: AppColors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 14,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      l.topTierReached,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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
