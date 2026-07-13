import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_gradients.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/bidi.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_choice_chips.dart';
import '../../../../core/widgets/gender_filter_chips.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../providers/leaderboard_providers.dart';

/// Coach/admin-only gender tag filter; players' boards are already scoped to
/// their own gender by the repository.
final _genderFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final tab = ref.watch(leaderboardTabProvider);
    final isMonthly = tab == 0;
    final board = ref.watch(leaderboardBoardProvider);
    final isEndorsements = board == 1;
    final entriesAsync = ref.watch(isEndorsements
        ? endorsementLeaderboardProvider
        : isMonthly
            ? monthlyLeaderboardProvider
            : allTimeLeaderboardProvider);
    final isCoach = ref.watch(currentUserProvider).value?.isCoach ?? false;
    final genderFilter = ref.watch(_genderFilterProvider);
    // Same icon as the score pills below — the switch and the numbers it
    // changes speak the same language.
    final scoreIcon =
        isEndorsements ? Icons.thumb_up : Icons.sports_volleyball;

    Future<void> refresh() async {
      ref.invalidate(monthlyLeaderboardProvider);
      ref.invalidate(allTimeLeaderboardProvider);
      ref.invalidate(endorsementLeaderboardProvider);
      await ref.read(isEndorsements
          ? endorsementLeaderboardProvider.future
          : isMonthly
              ? monthlyLeaderboardProvider.future
              : allTimeLeaderboardProvider.future);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l.leaderboard)),
      body: GradientBackground(
        child: Column(
        children: [
          // Board switch: games (attendance) vs endorsements. Endorsements
          // have no monthly slice — individual endorsement docs are private,
          // only the lifetime count is public — so the period toggle below
          // is games-only.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppChoiceChips<int>(
                value: board,
                quiet: true,
                onSelected: (v) =>
                    ref.read(leaderboardBoardProvider.notifier).state = v,
                options: [
                  AppChoiceChipOption(
                      value: 0,
                      label: l.games,
                      icon: Icons.sports_volleyball),
                  AppChoiceChipOption(
                      value: 1, label: l.endorsements, icon: Icons.thumb_up),
                ],
              ),
            ),
          ),
          // One quiet control row: gender filter (coaches only) at the
          // start, the period toggle tucked small at the end — nothing
          // shouts over the podium below. Skipped entirely when it would
          // be empty (player viewing endorsements).
          if (isCoach || !isEndorsements)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  // Players' boards are already gender-scoped by the
                  // repository, so only coaches/admins get the tag filter.
                  if (isCoach)
                    GenderFilterChips(
                      value: genderFilter,
                      onChanged: (v) =>
                          ref.read(_genderFilterProvider.notifier).state = v,
                      compact: true,
                    ),
                  if (!isEndorsements)
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: AppChoiceChips<int>(
                          value: tab,
                          quiet: true,
                          onSelected: (v) => ref
                              .read(leaderboardTabProvider.notifier)
                              .state = v,
                          options: [
                            AppChoiceChipOption(value: 0, label: l.thisMonth),
                            AppChoiceChipOption(value: 1, label: l.allTime),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // Name the metric the numbers below actually measure — without it
          // the podium's large numerals read as unexplained scores vs ranks.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                (isEndorsements
                        ? l.endorsementsAllTime
                        : isMonthly
                            ? l.gamesThisMonth
                            : l.gamesAllTime)
                    .toUpperCase(),
                style: AppTextStyles.eyebrow,
              ),
            ),
          ),
          // Players' boards are silently scoped to their own gender by the
          // repository — say so, or the "missing" players read as a bug.
          if (!isCoach)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  switch (
                      ref.watch(currentUserProvider).value?.gender) {
                    'male' => l.leaderboardMensBoard,
                    'female' => l.leaderboardWomensBoard,
                    _ => l.leaderboardSubtitle,
                  },
                  style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Expanded(
            child: entriesAsync.when(
              loading: () => const ListShimmer(
                  itemHeight: 68,
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 16)),
              error: (e, _) =>
                  ErrorView(icon: Icons.error_outline, onRetry: refresh),
              data: (allEntries) {
                final entries = !isCoach || genderFilter == 'all'
                    ? allEntries
                    : allEntries
                        .where((e) => e.gender == genderFilter)
                        .toList();
                if (entries.isEmpty) {
                  return EmptyStateView(
                    icon: isEndorsements
                        ? Icons.thumb_up_outlined
                        : Icons.emoji_events_outlined,
                    title: l.noLeaderboardData,
                  );
                }
                final myUid = ref.watch(currentUserProvider).value?.uid ?? '';
                // Standard competition ranking: equal counts share a rank
                // ("=1"), the next distinct count skips past them — so ties
                // never look like arbitrary ordering.
                final ranks = List<int>.filled(entries.length, 0);
                for (var i = 0; i < entries.length; i++) {
                  ranks[i] = i > 0 && entries[i].count == entries[i - 1].count
                      ? ranks[i - 1]
                      : i + 1;
                }
                final rankTallies = <int, int>{};
                for (final r in ranks) {
                  rankTallies[r] = (rankTallies[r] ?? 0) + 1;
                }
                bool isTied(int i) => (rankTallies[ranks[i]] ?? 0) > 1;
                // With a full podium (≥3), the top three become a podium header
                // and the remaining ranks (4+) list below it. Otherwise every
                // entry stays a plain tile.
                final hasPodium = entries.length >= 3;
                final restCount = hasPodium ? entries.length - 3 : entries.length;
                return RefreshIndicator(
                  onRefresh: refresh,
                  color: AppColors.gold,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: (hasPodium ? 1 : 0) + restCount,
                    itemBuilder: (_, i) {
                      if (hasPodium && i == 0) {
                        return _Podium(
                          top3: entries.sublist(0, 3),
                          ranks: ranks.sublist(0, 3),
                          tied: [isTied(0), isTied(1), isTied(2)],
                          currentUid: myUid,
                          scoreIcon: scoreIcon,
                        );
                      }
                      final idx = hasPodium ? i + 2 : i;
                      return AppStaggeredItem(
                        index: i,
                        child: _LeaderboardTile(
                          rank: ranks[idx],
                          isTied: isTied(idx),
                          entry: entries[idx],
                          isMe: entries[idx].uid == myUid,
                          scoreIcon: scoreIcon,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final bool isTied;
  final LeaderboardEntry entry;
  final bool isMe;

  /// Metric icon shown beside the score (volleyball for games, thumb for
  /// endorsements).
  final IconData scoreIcon;
  const _LeaderboardTile({
    required this.rank,
    this.isTied = false,
    required this.entry,
    this.isMe = false,
    required this.scoreIcon,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isTop3 = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.gold.withValues(alpha: 0.14)
            : isTop3
                ? AppColors.gold.withValues(alpha: 0.08)
                : AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
        border: (isMe || rank == 1)
            ? Border.all(color: AppColors.gold, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Center(
              // A shared rank shows as "=N" — honest about the tie; the
              // trophy is reserved for a sole #1.
              child: rank == 1 && !isTied
                  ? const Icon(Icons.emoji_events,
                          color: AppColors.gold, size: 24)
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(
                          duration: const Duration(milliseconds: 2000),
                          color: AppColors.white,
                          delay: const Duration(milliseconds: 1200))
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isTied ? '=$rank' : '#$rank',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isTop3 ? 18 : 15,
                          color: isTop3 ? AppColors.gold : AppColors.grey,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          // Same thin gold ring + shared initials fallback as every other
          // list avatar in the app.
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
              child: AppAvatar(
                name: entry.name,
                photoUrl: entry.photoUrl,
                radius: 19,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(bidiIsolate(entry.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                if (isMe) ...[
                  const SizedBox(width: 8),
                  _YouChip(l.youLabel),
                ],
              ],
            ),
          ),
          // The metric icon marks this number as the score, so it can never
          // be misread as another rank.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isTop3
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : AppColors.navyBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  scoreIcon,
                  size: 12,
                  color: isTop3 ? AppColors.gold : AppColors.grey,
                ),
                const SizedBox(width: 4),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: entry.count),
                  duration: AppMotion.slow,
                  curve: AppMotion.enter,
                  builder: (_, value, _) => Text(
                    '$value',
                    style: TextStyle(
                      color: isTop3 ? AppColors.gold : AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "You" pill used to mark the signed-in user's row / podium slot.
class _YouChip extends StatelessWidget {
  final String label;
  const _YouChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.navyBlue,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Podium for the top three (rendered only when there are ≥3 entries).
/// [top3] is descending: index 0 = #1, 1 = #2, 2 = #3; laid out #2 · #1 · #3.
/// [ranks]/[tied] carry the shared-rank story ("=1" on equal counts).
class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> top3;
  final List<int> ranks;
  final List<bool> tied;
  final String currentUid;
  final IconData scoreIcon;
  const _Podium({
    required this.top3,
    required this.ranks,
    required this.tied,
    required this.currentUid,
    required this.scoreIcon,
  });

  @override
  Widget build(BuildContext context) {
    return AppFadeIn(
      slide: 0.06,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _PodiumSlot(
                  entry: top3[1],
                  position: 2,
                  rank: ranks[1],
                  isTied: tied[1],
                  isMe: top3[1].uid == currentUid,
                  scoreIcon: scoreIcon),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PodiumSlot(
                  entry: top3[0],
                  position: 1,
                  rank: ranks[0],
                  isTied: tied[0],
                  isMe: top3[0].uid == currentUid,
                  scoreIcon: scoreIcon),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PodiumSlot(
                  entry: top3[2],
                  position: 3,
                  rank: ranks[2],
                  isTied: tied[2],
                  isMe: top3[2].uid == currentUid,
                  scoreIcon: scoreIcon),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final LeaderboardEntry entry;

  /// Visual pedestal slot (1 = center/tallest) — drives sizing only.
  final int position;

  /// Actual competition rank shown on the pedestal (can repeat on ties).
  final int rank;
  final bool isTied;
  final bool isMe;
  final IconData scoreIcon;
  const _PodiumSlot({
    required this.entry,
    required this.position,
    required this.rank,
    required this.isTied,
    required this.isMe,
    required this.scoreIcon,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isFirst = position == 1;
    final avatarRadius = isFirst ? 36.0 : 28.0;
    final pedestalHeight = isFirst ? 84.0 : (position == 2 ? 60.0 : 44.0);
    final ringAlpha = isFirst ? 1.0 : (position == 2 ? 0.7 : 0.5);

    final avatar = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isFirst ? AppGradients.goldCta : null,
        color: isFirst ? null : AppColors.gold.withValues(alpha: ringAlpha),
      ),
      child: AppAvatar(
        name: entry.name,
        photoUrl: entry.photoUrl,
        radius: avatarRadius,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 30,
          child: isFirst && !isTied
              ? const Icon(Icons.emoji_events, color: AppColors.gold, size: 28)
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(
                    duration: const Duration(milliseconds: 2200),
                    color: AppColors.white,
                    delay: const Duration(milliseconds: 1400),
                  )
              : null,
        ),
        avatar,
        const SizedBox(height: 8),
        Text(
          bidiIsolate(entry.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        if (isMe) ...[
          const SizedBox(height: 4),
          _YouChip(l.youLabel),
        ],
        const SizedBox(height: 4),
        // Metric icon beside the score: this numeral is the metric, the one
        // on the pedestal below is the rank.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              scoreIcon,
              size: isFirst ? 15 : 13,
              color: AppColors.gold,
            ),
            const SizedBox(width: 4),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: entry.count),
              duration: AppMotion.slow,
              curve: AppMotion.enter,
              builder: (_, value, _) => Text(
                '$value',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: isFirst ? 28 : 22,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: pedestalHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isFirst ? AppGradients.goldCta : null,
            color: isFirst ? null : AppColors.navyElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Text(
            isTied ? '=$rank' : '$rank',
            style: TextStyle(
              color: isFirst ? AppColors.navyBlue : AppColors.gold,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ),
      ],
    );
  }
}
