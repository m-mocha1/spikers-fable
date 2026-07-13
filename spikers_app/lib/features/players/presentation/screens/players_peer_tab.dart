import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/floating_nav_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/players_providers.dart';
import '../widgets/player_card.dart';

class PlayersPeerTab extends ConsumerWidget {
  const PlayersPeerTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final peersAsync = ref.watch(peersProvider);

    return peersAsync.when(
      loading: () => const ListShimmer(itemHeight: 80),
      error: (e, _) => ErrorView(onRetry: () => ref.invalidate(peersProvider)),
      data: (peers) {
        if (peers.isEmpty) {
          return EmptyStateView(icon: Icons.group_outlined, title: l.noPlayers);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
              16, 16, 16, FloatingNavBar.scrollClearance),
          itemCount: peers.length,
          itemBuilder: (_, i) {
            final peer = peers[i];
            return AppStaggeredItem(
              key: ValueKey(peer.uid),
              index: i,
              child: PlayerCard(
                name: peer.name,
                photoUrl: peer.photoUrl,
                injured: peer.injured,
                attendanceCount: peer.attendanceCount,
                onTap: () =>
                    context.push(Routes.playerProfile, extra: peer.uid),
              ),
            );
          },
        );
      },
    );
  }
}
