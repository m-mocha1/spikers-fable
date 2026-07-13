import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/attendance_tiers.dart';
import '../../../../core/utils/endorsement_level.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/level_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/profile_providers.dart';
import 'profile_stat_cards.dart' show profileCardChrome, tierLabel;

/// Rec. 709 luma matrix — desaturates locked badge art so earned badges are
/// the only full-color art in the case.
const _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// Trophy case: every games-played tier badge and endorsement level badge in
/// one card, earned ones in full color, locked ones greyscaled and dimmed
/// with their unlock threshold in the tooltip. Full colour alone carries the
/// earned state — no halo, per the one-glow-per-screen budget (Phase 6).
/// Purely derived from the two public counts, so it works for the signed-in
/// user's own profile and for viewing another player.
class AchievementsCard extends ConsumerWidget {
  final String uid;
  final AppLocalizations l;
  const AchievementsCard({super.key, required this.uid, required this.l});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(myAttendanceCountProvider(uid)).value;
    final endorsements = ref.watch(myEndorsementCountProvider(uid)).value;
    // Both derive from the same snapshot listener, so they land together.
    if (games == null || endorsements == null) return const SizedBox.shrink();

    final tier = AttendanceTiers.tierIndex(games);
    final level = endorsementLevel(endorsements);
    final earned = (tier + 1) + level;
    final total =
        AppAssets.gamesPlayedBadges.length + AppAssets.endorsementBadges.length;

    return AppFadeIn(
      slide: 0.06,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: profileCardChrome(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  size: 16,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.achievements,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$earned / $total',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _BadgeRow(
              caption: l.gamesPlayed,
              assets: AppAssets.gamesPlayedBadges,
              thresholds: [0, ...AttendanceTiers.thresholds],
              unlockedCount: tier + 1,
              labelFor: (i) => tierLabel(l, i),
              l: l,
            ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: AppColors.white.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 14),
            _BadgeRow(
              caption: l.endorsements,
              assets: AppAssets.endorsementBadges,
              thresholds: [0, ...endorsementThresholds],
              unlockedCount: level,
              labelFor: (i) => l.endorsementLevelLabel(i + 1),
              l: l,
            ),
          ],
        ),
      ),
    );
  }
}

/// One shelf of the trophy case: a quiet caption and five badge cells.
class _BadgeRow extends StatelessWidget {
  final String caption;
  final List<String> assets;
  final List<int> thresholds;
  final int unlockedCount;
  final String Function(int index) labelFor;
  final AppLocalizations l;
  const _BadgeRow({
    required this.caption,
    required this.assets,
    required this.thresholds,
    required this.unlockedCount,
    required this.labelFor,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption.toUpperCase(),
          style: const TextStyle(
            color: AppColors.grey,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < assets.length; i++)
              Expanded(
                child: _BadgeCell(
                  asset: assets[i],
                  unlocked: i < unlockedCount,
                  label: labelFor(i),
                  threshold: thresholds[i],
                  l: l,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BadgeCell extends StatelessWidget {
  final String asset;
  final bool unlocked;
  final String label;
  final int threshold;
  final AppLocalizations l;
  const _BadgeCell({
    required this.asset,
    required this.unlocked,
    required this.label,
    required this.threshold,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    // LevelBadge's own tooltip is skipped (label: null) — the cell wraps badge
    // and name together so locked cells can explain their unlock threshold.
    final badge = LevelBadge(asset: asset, size: 44);
    return Tooltip(
      message: unlocked ? label : l.unlocksAt(threshold),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          unlocked
              ? badge
              : Opacity(
                  opacity: 0.35,
                  child: ColorFiltered(colorFilter: _greyscale, child: badge),
                ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: unlocked
                  ? AppColors.gold
                  : AppColors.white.withValues(alpha: 0.60),
            ),
          ),
        ],
      ),
    );
  }
}
