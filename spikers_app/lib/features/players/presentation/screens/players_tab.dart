import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/age_calculator.dart';
import '../../../../core/widgets/gender_filter_chips.dart';
import '../../../../core/widgets/injured_icon.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/player_summary.dart';
import '../providers/players_providers.dart';
import '../widgets/payment_confirm_dialog.dart';

final _genderFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');

class PlayersTab extends ConsumerStatefulWidget {
  const PlayersTab({super.key});

  @override
  ConsumerState<PlayersTab> createState() => _PlayersTabState();
}

class _PlayersTabState extends ConsumerState<PlayersTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final playersAsync = ref.watch(playersProvider);
    final genderFilter = ref.watch(_genderFilterProvider);

    return playersAsync.when(
      loading: () => const ListShimmer(),
      error: (e, _) =>
          ErrorView(onRetry: () => ref.invalidate(playersProvider)),
      data: (players) {
        final q = _query.trim().toLowerCase();
        final filtered = players.where((p) {
          final matchesGender =
              genderFilter == 'all' || p.gender == genderFilter;
          final matchesQuery = q.isEmpty || p.name.toLowerCase().contains(q);
          return matchesGender && matchesQuery;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  GenderFilterChips(
                    value: genderFilter,
                    onChanged: (v) =>
                        ref.read(_genderFilterProvider.notifier).state = v,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: l.searchPlayers,
                        hintStyle: const TextStyle(
                          color: AppColors.grey,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.grey,
                          size: 20,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.close,
                                  color: AppColors.grey,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        filled: true,
                        fillColor: AppColors.navyLight,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? EmptyStateView(
                      icon: Icons.group_outlined,
                      title: q.isEmpty ? l.noPlayers : l.noPlayersMatch,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _PlayerCard(
                        key: ValueKey(filtered[i].uid),
                        player: filtered[i],
                        l: l,
                        onTapBadge: () => confirmTogglePayment(
                          context,
                          ref,
                          uid: filtered[i].uid,
                          name: filtered[i].name,
                          paidUntil: filtered[i].paidUntil,
                          isLifetime: filtered[i].lifetimeMember,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final PlayerSummary player;
  final AppLocalizations l;
  final VoidCallback onTapBadge;
  const _PlayerCard({
    super.key,
    required this.player,
    required this.l,
    required this.onTapBadge,
  });

  @override
  Widget build(BuildContext context) {
    final age = player.dateOfBirth == null
        ? 0
        : AgeCalculator.fromDate(player.dateOfBirth!);
    final initials = player.name.trim().isEmpty
        ? '?'
        : player.name
              .trim()
              .split(' ')
              .map((w) => w[0])
              .take(2)
              .join()
              .toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(Routes.playerProfile, extra: player.uid),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                  backgroundImage: player.photoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(player.photoUrl)
                      : null,
                  child: player.photoUrl.isEmpty
                      ? Text(
                          initials,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              player.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (player.injured) ...[
                            const SizedBox(width: 6),
                            const InjuredIcon(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '$age ${l.years}',
                            style: const TextStyle(
                              color: AppColors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.sports_volleyball,
                            size: 11,
                            color: AppColors.grey,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${player.attendanceCount} ${l.sessionsAttended}',
                            style: const TextStyle(
                              color: AppColors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _PaidBadge(
                  isPaid: player.isPaid,
                  daysLeft: player.paymentDaysLeft,
                  isLifetime: player.lifetimeMember,
                  onTap: onTapBadge,
                  l: l,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaidBadge extends StatelessWidget {
  final bool isPaid;
  final int daysLeft;
  final bool isLifetime;
  final VoidCallback onTap;
  final AppLocalizations l;
  const _PaidBadge({
    required this.isPaid,
    required this.daysLeft,
    required this.isLifetime,
    required this.onTap,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (isLifetime) {
      color = AppColors.gold;
    } else if (!isPaid || daysLeft == 0) {
      color = AppColors.errorRed;
    } else if (daysLeft <= 9) {
      color = AppColors.warning;
    } else {
      color = AppColors.success;
    }
    final showDays = !isLifetime && isPaid && daysLeft <= 9;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isLifetime ? l.lifetime : (isPaid ? l.paid : l.unpaid),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            if (showDays)
              Text(
                l.daysLeft(daysLeft),
                style: TextStyle(color: color, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }
}

