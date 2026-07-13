import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_gradients.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/attendance_tiers.dart';
import '../../../../core/utils/bidi.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/injured_icon.dart';
import '../../../../core/widgets/level_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/profile_stat_cards.dart'
    show tierLabel;

/// Premium roster row shared by the coach roster (players tab), the
/// player-facing peer list and the coaches screen. Presentation only —
/// everything shown is derived from the summary the caller already holds.
///
/// Hierarchy: name first, quiet one-line meta underneath, then the attendance
/// story as a thin gold bar filling toward the next milestone tier (the same
/// thresholds as the profile's games-played card, so the two never disagree).
/// The avatar carries the tier's badge art docked on its corner, so a player's
/// standing is readable at a glance while scrolling.
///
/// Rows without an attendance story (coaches — `CoachSummary` carries no
/// attendance data) pass a null [attendanceCount] plus a [roleLabel]: the
/// tier badge, meta line and progress bar all drop away and the quiet gold
/// role eyebrow takes their place.
class PlayerCard extends StatelessWidget {
  final String name;
  final String photoUrl;
  final bool injured;

  /// Null hides the entire attendance story (badge, meta line, tier bar).
  final int? attendanceCount;

  /// Quiet gold eyebrow under the name for rows with no attendance story
  /// (e.g. "COACH").
  final String? roleLabel;

  /// Hidden when null (peer rows, or a coach row with no date of birth).
  final int? age;

  /// Coach roster passes the payment badge; when null a quiet chevron takes
  /// its place so the row still reads as tappable.
  final Widget? trailing;

  final VoidCallback onTap;

  const PlayerCard({
    super.key,
    required this.name,
    required this.photoUrl,
    this.injured = false,
    this.attendanceCount,
    this.roleLabel,
    this.age,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tier = attendanceCount == null
        ? null
        : AttendanceTiers.tierIndex(attendanceCount!);

    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.07)),
          // Softer than the session cards' shadow — the roster is a dense
          // list, so each row gets a whisper of lift rather than a poster
          // drop.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _TieredAvatar(name: name, photoUrl: photoUrl, tier: tier, l: l),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          bidiIsolate(name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      if (injured) ...[
                        const SizedBox(width: 6),
                        const InjuredIcon(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (attendanceCount != null) ...[
                    Row(
                      children: [
                        if (age != null)
                          Text(
                            '${l.ageYears(age!)} · ',
                            style: const TextStyle(
                              color: AppColors.grey,
                              fontSize: 12,
                            ),
                          ),
                        const Icon(
                          Icons.sports_volleyball,
                          size: 11,
                          color: AppColors.grey,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          // Short plural ("12 sessions") instead of the full
                          // "sessions attended" phrase — the meta line shares
                          // its row with the age and must survive 360dp next
                          // to the trailing membership chip without clipping.
                          child: Text(
                            l.sessionsCount(attendanceCount!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _TierProgressBar(
                            count: attendanceCount!,
                            tier: tier!,
                            l: l,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tierLabel(l, tier).toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ] else if (roleLabel != null)
                    Text(
                      roleLabel!.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.eyebrow,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing ??
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left
                      : Icons.chevron_right,
                  size: 20,
                  color: AppColors.white.withValues(alpha: 0.30),
                ),
          ],
        ),
      ),
    );
  }
}

/// Avatar inside a thin gold gradient ring (with a navy gap so the ring reads
/// as a ring, not a border), with the player's games-played tier badge art
/// docked on the corner. A null [tier] (no attendance story — coaches) leaves
/// a plain ringed avatar, as does missing badge art ([LevelBadge]'s
/// errorBuilder).
class _TieredAvatar extends StatelessWidget {
  final String name;
  final String photoUrl;
  final int? tier;
  final AppLocalizations l;
  const _TieredAvatar({
    required this.name,
    required this.photoUrl,
    required this.tier,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final ring = Container(
      padding: const EdgeInsets.all(1.6),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.goldCta,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.navyLight,
        ),
        child: AppAvatar(name: name, photoUrl: photoUrl, radius: 21),
      ),
    );

    if (tier == null) return ring;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ring,
        PositionedDirectional(
          bottom: -3,
          end: -3,
          child: Container(
            // Navy backing circle separates the badge art from the photo —
            // kept hairline-thin so the badge art dominates, not the disc.
            padding: const EdgeInsets.all(1),
            decoration: const BoxDecoration(
              color: AppColors.navyLight,
              shape: BoxShape.circle,
            ),
            child: LevelBadge(
              asset: AppAssets.gamesPlayedBadges[tier!],
              size: 23,
              label: tierLabel(l, tier!),
            ),
          ),
        ),
      ],
    );
  }
}

/// Thin gold meter showing progress *within* the current tier toward the next
/// milestone (full at Champion). Same fill-on-mount motion as the session
/// card's capacity bar so the two lists share one visual grammar. Long-press
/// reveals how many sessions remain to the next tier.
class _TierProgressBar extends StatelessWidget {
  final int count;
  final int tier;
  final AppLocalizations l;
  const _TierProgressBar({
    required this.count,
    required this.tier,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final int? next = tier < AttendanceTiers.thresholds.length
        ? AttendanceTiers.thresholds[tier]
        : null;
    final prev = tier == 0 ? 0 : AttendanceTiers.thresholds[tier - 1];
    final ratio = next == null
        ? 1.0
        : ((count - prev) / (next - prev)).clamp(0.0, 1.0);

    return Tooltip(
      message: next == null
          ? tierLabel(l, tier)
          : l.toNextTier(next - count, tierLabel(l, tier + 1)),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: ratio),
        duration: AppMotion.slow,
        curve: AppMotion.enter,
        builder: (context, value, child) => Container(
          height: 3.5,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(2),
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
