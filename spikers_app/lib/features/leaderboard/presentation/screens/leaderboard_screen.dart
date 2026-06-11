import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
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
      appBar: AppBar(title: Text(l.leaderboard)),
      body: Column(
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
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: AppColors.grey),
                    const SizedBox(height: 16),
                    Text(l.errorOccurred,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: refresh,
                      child: Text(l.retry,
                          style: const TextStyle(color: AppColors.gold)),
                    ),
                  ],
                ),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.emoji_events_outlined,
                            size: 64, color: AppColors.grey),
                        const SizedBox(height: 16),
                        Text(l.noLeaderboardData,
                            style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: refresh,
                  color: AppColors.gold,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: entries.length,
                    itemBuilder: (_, i) =>
                        _LeaderboardTile(rank: i + 1, entry: entries[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  const _LeaderboardTile({required this.rank, required this.entry});

  @override
  Widget build(BuildContext context) {
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
        color: isTop3
            ? AppColors.gold.withValues(alpha: 0.08)
            : AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
        border: rank == 1 ? Border.all(color: AppColors.gold, width: 1.5) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Center(
              child: rank == 1
                  ? const Icon(Icons.emoji_events,
                      color: AppColors.gold, size: 24)
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
            child: Text(entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isTop3
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : AppColors.navyBlue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${entry.count}',
              style: TextStyle(
                color: isTop3 ? AppColors.gold : AppColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
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
