import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_gradients.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/age_calculator.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/gender_filter_chips.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/players_providers.dart';
import '../widgets/payment_confirm_dialog.dart';
import '../widgets/player_card.dart';

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
      loading: () => const ListShimmer(itemHeight: 86),
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
            // Search on its own full-width row, filters underneath — gives
            // the search field room to breathe instead of fighting the chips
            // for one line.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _SearchField(
                controller: _searchController,
                query: _query,
                hint: l.searchPlayers,
                onChanged: (v) => setState(() => _query = v),
                onClear: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GenderFilterChips(
                    value: genderFilter,
                    onChanged: (v) =>
                        ref.read(_genderFilterProvider.notifier).state = v,
                  ),
                  const Spacer(),
                  _ResultCountPill(count: filtered.length, l: l),
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final p = filtered[i];
                        return AppStaggeredItem(
                          key: ValueKey(p.uid),
                          index: i,
                          child: PlayerCard(
                            name: p.name,
                            photoUrl: p.photoUrl,
                            injured: p.injured,
                            attendanceCount: p.attendanceCount,
                            age: p.dateOfBirth == null
                                ? null
                                : AgeCalculator.fromDate(p.dateOfBirth!),
                            onTap: () => context.push(
                              Routes.playerProfile,
                              extra: p.uid,
                            ),
                            trailing: _PaidBadge(
                              isPaid: p.isPaid,
                              daysLeft: p.paymentDaysLeft,
                              isLifetime: p.lifetimeMember,
                              l: l,
                              onTap: () => confirmTogglePayment(
                                context,
                                ref,
                                uid: p.uid,
                                name: p.name,
                                paidUntil: p.paidUntil,
                                isLifetime: p.lifetimeMember,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Full-width rounded search field. Hairline border at rest, gold when
/// focused, matching the card borders used across the app.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchField({
    required this.controller,
    required this.query,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: color),
    );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      cursorColor: AppColors.gold,
      style: const TextStyle(color: AppColors.white, fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.grey, fontSize: 13.5),
        prefixIcon: const Icon(Icons.search, color: AppColors.grey, size: 20),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 42,
          minHeight: 42,
        ),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.close,
                  color: AppColors.grey,
                  size: 18,
                ),
                onPressed: onClear,
              ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 42,
          minHeight: 42,
        ),
        filled: true,
        fillColor: AppColors.navyLight,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        enabledBorder: border(AppColors.white.withValues(alpha: 0.08)),
        focusedBorder: border(AppColors.gold.withValues(alpha: 0.55)),
        border: border(Colors.transparent),
      ),
    );
  }
}

/// Quiet live count of the rows the current search + gender filter produce —
/// instant feedback that a filter actually did something. Same pill style as
/// the sessions tab's section count.
class _ResultCountPill extends StatelessWidget {
  final int count;
  final AppLocalizations l;
  const _ResultCountPill({required this.count, required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: AppMotion.fast,
            child: Text(
              '$count',
              key: ValueKey(count),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            l.players,
            style: const TextStyle(
              color: AppColors.grey,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    final IconData icon;
    if (isLifetime) {
      color = AppColors.gold;
      icon = Icons.workspace_premium;
    } else if (!isPaid || daysLeft == 0) {
      color = AppColors.errorRed;
      icon = Icons.error_outline;
    } else if (daysLeft <= 9) {
      color = AppColors.warning;
      icon = Icons.schedule;
    } else {
      color = AppColors.success;
      icon = Icons.check_circle_outline;
    }
    final showDays = !isLifetime && isPaid && daysLeft <= 9;
    // Lifetime members get the solid gold-gradient treatment; everyone else
    // stays on the tinted-outline pill so lifetime reads as the special case.
    final fg = isLifetime ? AppColors.navyBlue : color;

    // InkWell + outer padding: a ripple on tap and a ≥44px hit area for what
    // is the coach's most-tapped control, without growing the pill visually.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: isLifetime ? AppGradients.goldCta : null,
              color: isLifetime ? null : color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: isLifetime ? null : Border.all(color: color),
              boxShadow: isLifetime
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 5),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLifetime ? l.lifetime : (isPaid ? l.paid : l.unpaid),
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                    if (showDays)
                      Text(
                        l.daysLeft(daysLeft),
                        style: TextStyle(color: fg, fontSize: 9.5),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
