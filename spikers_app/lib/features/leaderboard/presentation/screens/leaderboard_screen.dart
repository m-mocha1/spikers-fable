import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_gradients.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../providers/leaderboard_providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final tab = ref.watch(leaderboardTabProvider);
    final isMonthly = tab == 0;
    final entriesAsync = ref.watch(
        isMonthly ? monthlyLeaderboardProvider : allTimeLeaderboardProvider);

    Future<void> refresh() async {
      ref.invalidate(monthlyLeaderboardProvider);
      ref.invalidate(allTimeLeaderboardProvider);
      await ref.read(isMonthly
          ? monthlyLeaderboardProvider.future
          : allTimeLeaderboardProvider.future);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l.leaderboard)),
      body: GradientBackground(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _Chip(
                  label: l.thisMonth,
                  active: tab == 0,
                  onTap: () =>
                      ref.read(leaderboardTabProvider.notifier).state = 0,
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: l.allTime,
                  active: tab == 1,
                  onTap: () =>
                      ref.read(leaderboardTabProvider.notifier).state = 1,
                ),
              ],
            ),
          ),
          Expanded(
            child: entriesAsync.when(
              loading: () => const ListShimmer(
                  itemHeight: 68,
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 16)),
              error: (e, _) =>
                  ErrorView(icon: Icons.error_outline, onRetry: refresh),
              data: (entries) {
                if (entries.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.emoji_events_outlined,
                    title: l.noLeaderboardData,
                  );
                }
                final myUid = ref.watch(currentUserProvider).value?.uid ?? '';
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
                          currentUid: myUid,
                        );
                      }
                      final idx = hasPodium ? i + 2 : i;
                      return AppStaggeredItem(
                        index: i,
                        child: _LeaderboardTile(
                          rank: idx + 1,
                          entry: entries[idx],
                          isMe: entries[idx].uid == myUid,
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
  final LeaderboardEntry entry;
  final bool isMe;
  const _LeaderboardTile({
    required this.rank,
    required this.entry,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isTop3 = rank <= 3;
    final initials = entry.name.trim().isEmpty
        ? '?'
        : entry.name
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();

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
              child: rank == 1
                  ? const Icon(Icons.emoji_events,
                          color: AppColors.gold, size: 24)
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(
                          duration: const Duration(milliseconds: 2000),
                          color: AppColors.white,
                          delay: const Duration(milliseconds: 1200))
                  : Text(
                      '#$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: isTop3 ? 18 : 15,
                        color: isTop3 ? AppColors.gold : AppColors.grey,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.gold.withValues(alpha: 0.2),
            backgroundImage: entry.photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(entry.photoUrl)
                : null,
            child: entry.photoUrl.isEmpty
                ? Text(initials,
                    style: const TextStyle(
                        color: AppColors.gold, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(entry.name,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isTop3
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : AppColors.navyBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TweenAnimationBuilder<int>(
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
class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> top3;
  final String currentUid;
  const _Podium({required this.top3, required this.currentUid});

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
                  entry: top3[1], rank: 2, isMe: top3[1].uid == currentUid),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PodiumSlot(
                  entry: top3[0], rank: 1, isMe: top3[0].uid == currentUid),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PodiumSlot(
                  entry: top3[2], rank: 3, isMe: top3[2].uid == currentUid),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final bool isMe;
  const _PodiumSlot({
    required this.entry,
    required this.rank,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isFirst = rank == 1;
    final avatarRadius = isFirst ? 36.0 : 28.0;
    final pedestalHeight = isFirst ? 84.0 : (rank == 2 ? 60.0 : 44.0);
    final ringAlpha = isFirst ? 1.0 : (rank == 2 ? 0.7 : 0.5);

    final initials = entry.name.trim().isEmpty
        ? '?'
        : entry.name
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();

    final avatar = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isFirst ? AppGradients.goldCta : null,
        color: isFirst ? null : AppColors.gold.withValues(alpha: ringAlpha),
      ),
      child: CircleAvatar(
        radius: avatarRadius,
        backgroundColor: AppColors.navyElevated,
        backgroundImage: entry.photoUrl.isNotEmpty
            ? CachedNetworkImageProvider(entry.photoUrl)
            : null,
        child: entry.photoUrl.isEmpty
            ? Text(
                initials,
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: isFirst ? 20 : 16,
                ),
              )
            : null,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 30,
          child: isFirst
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
          entry.name,
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
            '$rank',
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

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.gold : AppColors.navyLight,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: active ? AppColors.gold : AppColors.grey),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.navyBlue : AppColors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
