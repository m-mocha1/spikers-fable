import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_gradients.dart';
import 'app_avatar.dart';
import 'level_badge.dart';

/// Profile-hero avatar ringed in the brand's gold gradient, with a navy gap so
/// the ring reads as a ring rather than a border — a plain gold stroke, no
/// halo, per the app's one-glow-per-screen budget (Premium Pass Phase 6).
/// Optionally docks the player's tier badge art on the corner — the large
/// sibling of the roster row's small tiered avatar, so a player's standing
/// reads the same everywhere.
class RingedAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;

  /// Radius of the inner photo circle (the ring adds ~12px overall).
  final double radius;

  /// Tier badge art docked bottom-end; omitted when null (e.g. still loading).
  final String? badgeAsset;
  final String? badgeLabel;

  const RingedAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 64,
    this.badgeAsset,
    this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ring = Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.goldCta,
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.navyBlue,
        ),
        child: AppAvatar(name: name, photoUrl: photoUrl, radius: radius),
      ),
    );

    if (badgeAsset == null) return ring;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ring,
        PositionedDirectional(
          bottom: 2,
          end: 2,
          child: Container(
            // Navy backing circle separates the badge art from the photo —
            // kept hairline-thin so the badge art dominates, not the disc.
            padding: const EdgeInsets.all(1),
            decoration: const BoxDecoration(
              color: AppColors.navyBlue,
              shape: BoxShape.circle,
            ),
            child: LevelBadge(
              asset: badgeAsset!,
              size: radius * 0.85,
              label: badgeLabel,
            ),
          ),
        ),
      ],
    );
  }
}
