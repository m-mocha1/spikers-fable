import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/player_summary.dart';
import '../providers/players_providers.dart';

class PlayersPeerTab extends ConsumerWidget {
  const PlayersPeerTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final peersAsync = ref.watch(peersProvider);

    return peersAsync.when(
      loading: () => const ListShimmer(),
      error: (e, _) =>
          ErrorView(onRetry: () => ref.invalidate(peersProvider)),
      data: (peers) {
        if (peers.isEmpty) {
          return EmptyStateView(
              icon: Icons.group_outlined, title: l.noPlayers);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: peers.length,
          itemBuilder: (_, i) => AppStaggeredItem(
            index: i,
            child: _PeerCard(peer: peers[i], l: l),
          ),
        );
      },
    );
  }
}

class _PeerCard extends StatelessWidget {
  final PeerSummary peer;
  final AppLocalizations l;
  const _PeerCard({required this.peer, required this.l});

  @override
  Widget build(BuildContext context) {
    final initials = peer.name.trim().isEmpty
        ? '?'
        : peer.name
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
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.gold.withValues(alpha: 0.2),
            backgroundImage: peer.photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(peer.photoUrl)
                : null,
            child: peer.photoUrl.isEmpty
                ? Text(initials,
                    style: const TextStyle(
                        color: AppColors.gold, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(peer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.sports_volleyball,
                        size: 11, color: AppColors.grey),
                    const SizedBox(width: 4),
                    Text('${peer.attendanceCount} ${l.sessionsAttended}',
                        style: const TextStyle(
                            color: AppColors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
