import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_gradients.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/utils/attendance_tiers.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/injured_icon.dart';
import '../../../../core/widgets/level_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/profile_stat_cards.dart'
    show tierLabel;

/// Premium roster row shared by the coach roster (players tab) and the
/// player-facing peer list. Presentation only — everything shown is derived
/// from the summary the caller already holds.
///
/// Hierarchy: name first, quiet one-line meta underneath, then the attendance
/// story as a thin gold bar filling toward the next milestone tier (the same
/// thresholds as the profile's games-played card, so the two never disagree).
/// The avatar carries the tier's badge art docked on its corner, so a player's
/// standing is readable at a glance while scrolling.
class PlayerCard extends StatelessWidget {
  final String name;
  final String photoUrl;
  final bool injured;
  final int attendanceCount;

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
    required this.injured,
    required this.attendanceCount,
    this.age,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tier = AttendanceTiers.tierIndex(attendanceCount);

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
                          name,
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
                  Row(
                    children: [
                      if (age != null)
                        Text(
                          '$age ${l.years} · ',
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
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$attendanceCount ',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: l.sessionsAttended),
                            ],
                          ),
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
                          count: attendanceCount,
                          tier: tier,
                          l: l,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tierLabel(l, tier).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
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
/// docked on the corner. The badge degrades to nothing if the art is missing
/// ([LevelBadge]'s errorBuilder), leaving a plain ringed avatar.
class _TieredAvatar extends StatelessWidget {
  final String name;
  final String photoUrl;
  final int tier;
  final AppLocalizations l;
  const _TieredAvatar({
    required this.name,
    required this.photoUrl,
    required this.tier,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
              .trim()
              .split(' ')
              .map((w) => w[0])
              .take(2)
              .join()
              .toUpperCase();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
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
            child: CircleAvatar(
              radius: 21,
              backgroundColor: AppColors.gold.withValues(alpha: 0.18),
              backgroundImage: photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
              child: photoUrl.isEmpty
                  ? Text(
                      initials,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        PositionedDirectional(
          bottom: -3,
          end: -3,
          child: Container(
            // Navy backing circle separates the badge art from the photo.
            padding: const EdgeInsets.all(1.5),
            decoration: const BoxDecoration(
              color: AppColors.navyLight,
              shape: BoxShape.circle,
            ),
            child: LevelBadge(
              asset: AppAssets.gamesPlayedBadges[tier],
              size: 19,
              label: tierLabel(l, tier),
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
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.40),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
