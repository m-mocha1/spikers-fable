import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/age_calculator.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/floating_nav_bar.dart';
import '../../../../core/widgets/gender_filter_chips.dart';
import '../../../../core/widgets/membership_chip.dart';
import '../../../../core/widgets/retracting_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sessions/domain/entities/player_group_model.dart';
import '../../../sessions/domain/player_group_selection.dart';
import '../../../sessions/presentation/providers/sessions_providers.dart';
import '../../../sessions/presentation/widgets/player_group_actions.dart';
import '../../../sessions/presentation/widgets/member_picker_sheet.dart';
import '../../../sessions/presentation/widgets/player_group_rail.dart';
import '../providers/players_providers.dart';
import '../widgets/membership_sheet.dart';
import '../widgets/player_card.dart';
import '../widgets/player_sort_chip.dart';

final _genderFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');

/// Ids of the saved player groups the coach has applied as a filter. Combinable:
/// several groups layer into one union, matching how the same chips behave when
/// building a custom session.
final _groupFilterProvider =
    StateProvider.autoDispose<Set<String>>((ref) => const {});
final _sortProvider =
    StateProvider.autoDispose<PlayerSort>((ref) => PlayerSort.name);

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

  /// Reopens the member picker seeded with the group, then saves the result —
  /// the same edit the create-session rail offers, so a coach can correct a
  /// group's roster from wherever they notice it is wrong.
  Future<void> _editGroupMembers(PlayerGroup group) async {
    final updated =
        await showMemberPicker(context, initial: group.memberIds.toSet());
    if (updated == null || !mounted) return;
    await saveGroupMembers(context, ref, group, updated);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final playersAsync = ref.watch(playersProvider);
    final genderFilter = ref.watch(_genderFilterProvider);
    final sort = ref.watch(_sortProvider);
    // Empty for anyone who isn't staff (the provider gates on isCoach), so the
    // rail can't render for a player even if this tab were somehow reached.
    final groups = ref.watch(playerGroupsProvider).valueOrNull ?? const [];
    final groupFilter = ref.watch(_groupFilterProvider);

    return playersAsync.when(
      loading: () => const ListShimmer(itemHeight: 86),
      error: (e, _) =>
          ErrorView(onRetry: () => ref.invalidate(playersProvider)),
      data: (players) {
        final q = _query.trim().toLowerCase();
        // Resolved against the live roster so a group still listing a deleted
        // player doesn't filter the list down to nothing.
        final rosterUids = players.map((p) => p.uid).toSet();
        final groupUids = unionMembers(groups, groupFilter, rosterUids);
        final filtered = sort.apply(players.where((p) {
          final matchesGender =
              genderFilter == 'all' || p.gender == genderFilter;
          final matchesQuery = q.isEmpty || p.name.toLowerCase().contains(q);
          final matchesGroup =
              groupFilter.isEmpty || groupUids.contains(p.uid);
          return matchesGender && matchesQuery && matchesGroup;
        }).toList());

        // Search + filters retract on scroll-down and return on scroll-up so
        // the roster gets the full screen height once the user starts browsing.
        final header = Column(
          mainAxisSize: MainAxisSize.min,
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
                  // Expanded gives the chips bounded width (AppChoiceChips
                  // requirement) and pushes the count pill to the end.
                  Expanded(
                    child: GenderFilterChips(
                      value: genderFilter,
                      onChanged: (v) =>
                          ref.read(_genderFilterProvider.notifier).state = v,
                    ),
                  ),
                  PlayerSortChip(
                    value: sort,
                    onChanged: (v) => ref.read(_sortProvider.notifier).state = v,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _ResultCountPill(count: filtered.length, l: l),
                ],
              ),
            ),
            // Saved groups get their own row: the row above is already four
            // controls wide at 360dp. One scrolling line rather than a wrap, so
            // the strip keeps the same left edge as the search field above it
            // however many groups there are. Long-press manages a group —
            // rename, edit members, or delete.
            if (groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Semantics(
                  label: l.filterByGroup,
                  child: PlayerGroupRail(
                    groups: groups,
                    appliedGroupIds: groupFilter,
                    scrollable: true,
                    onApply: (g) {
                      final next = {...groupFilter};
                      if (!next.remove(g.id)) next.add(g.id);
                      ref.read(_groupFilterProvider.notifier).state = next;
                    },
                    onManage: (g) => manageGroup(context, ref, g,
                        onEditMembers: () => _editGroupMembers(g)),
                  ),
                ),
              ),
          ],
        );

        return RetractingHeader(
          header: header,
          child: filtered.isEmpty
              ? EmptyStateView(
                  icon: Icons.group_outlined,
                  title: q.isEmpty ? l.noPlayers : l.noPlayersMatch,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      16, 20, 16, FloatingNavBar.scrollClearance),
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
                        trailing: MembershipChip(
                          isPaid: p.isPaid,
                          daysLeft: p.paymentDaysLeft,
                          isLifetime: p.lifetimeMember,
                          // LIFETIME is this screen's one glowing element.
                          emphasized: true,
                          onTap: () => showMembershipSheet(
                            context,
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
                tooltip: AppLocalizations.of(context)!.clearSearch,
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
            l.players(count),
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
