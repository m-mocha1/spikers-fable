import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/branded_button.dart';
import '../../../../core/widgets/gender_filter_chips.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../players/domain/entities/player_summary.dart';
import '../../../players/presentation/providers/players_providers.dart';
import '../../domain/entities/player_group_model.dart';
import '../../domain/player_group_selection.dart';
import '../providers/sessions_providers.dart';
import 'player_group_actions.dart';
import 'player_group_rail.dart';

/// Opens a modal bottom sheet that lets a coach pick players. Returns the
/// chosen uid set, or null if dismissed without confirming. [initial]
/// pre-selects members.
///
/// Defaults to its original job — choosing the members of a custom session.
/// The optional parameters let the same sheet serve the coach-side "add
/// players to this session" flow instead: [restrictTo] closes the pool to a
/// fixed set of uids (a custom session's members, so a late add can't smuggle
/// in an outsider), [excludeUids] hides players already on the roster, and
/// [title]/[confirmLabel]/[allowSaveAsGroup] re-word the sheet for that
/// context.
Future<Set<String>?> showMemberPicker(
  BuildContext context, {
  required Set<String> initial,
  Set<String>? restrictTo,
  Set<String> excludeUids = const {},
  String? title,
  String? confirmLabel,
  bool allowSaveAsGroup = true,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navyBlue,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _MemberPickerSheet(
      initial: initial,
      restrictTo: restrictTo,
      excludeUids: excludeUids,
      title: title,
      confirmLabel: confirmLabel,
      allowSaveAsGroup: allowSaveAsGroup,
    ),
  );
}

class _MemberPickerSheet extends ConsumerStatefulWidget {
  final Set<String> initial;
  final Set<String>? restrictTo;
  final Set<String> excludeUids;
  final String? title;
  final String? confirmLabel;
  final bool allowSaveAsGroup;
  const _MemberPickerSheet({
    required this.initial,
    this.restrictTo,
    this.excludeUids = const {},
    this.title,
    this.confirmLabel,
    this.allowSaveAsGroup = true,
  });

  @override
  ConsumerState<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends ConsumerState<_MemberPickerSheet> {
  final _searchController = TextEditingController();
  late final Set<String> _selected = {...widget.initial};
  // Fresh view: no group is highlighted until the coach explicitly taps one,
  // even if the incoming selection already covers it.
  final Set<String> _appliedGroupIds = {};
  String _query = '';
  String _genderFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Toggles a saved group in/out of the selection, updating both the member
  /// set and the applied-group highlight. Overlap-safe and restricted to
  /// players that still exist.
  void _applyGroup(
      PlayerGroup g, List<PlayerGroup> groups, Set<String>? validUids) {
    final result = toggleGroup(
      group: g,
      allGroups: groups,
      selected: _selected,
      appliedGroupIds: _appliedGroupIds,
      validUids: validUids,
    );
    setState(() {
      _selected
        ..clear()
        ..addAll(result.selected);
      _appliedGroupIds
        ..clear()
        ..addAll(result.appliedGroupIds);
    });
  }

  /// After a manual check/uncheck, drop any applied group no longer fully
  /// selected so its chip stops falsely showing as applied.
  void _syncAppliedGroups(List<PlayerGroup> groups, Set<String>? validUids) {
    final reconciled = reconcileAppliedGroups(
      allGroups: groups,
      appliedGroupIds: _appliedGroupIds,
      selected: _selected,
      validUids: validUids,
    );
    _appliedGroupIds
      ..clear()
      ..addAll(reconciled);
  }

  /// Whether [p] may be offered by this sheet at all. Separate from the
  /// search/gender filters: those narrow what is shown, this decides what
  /// exists here.
  bool _inPool(PlayerSummary p) {
    final restrict = widget.restrictTo;
    if (restrict != null && !restrict.contains(p.uid)) return false;
    return !widget.excludeUids.contains(p.uid);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final playersAsync = ref.watch(playersProvider);
    final groups = ref.watch(playerGroupsProvider).valueOrNull ?? const [];
    // Group chips resolve against the pool, not the whole roster, so tapping a
    // group can never pull in someone the pool excludes.
    final pool = playersAsync.valueOrNull?.where(_inPool).toList();
    final validUids = pool?.map((p) => p.uid).toSet();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title ?? l.chooseMembers,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    l.membersSelected(_selected.length),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Saved groups: tap to fill the selection, long-press to manage.
            if (groups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: PlayerGroupRail(
                  groups: groups,
                  appliedGroupIds: _appliedGroupIds,
                  onApply: (g) => _applyGroup(g, groups, validUids),
                  // "Update to current selection" only makes sense while the
                  // selection *is* a member list; in the add-players flow it is
                  // a throwaway pick, so the group keeps its own roster.
                  onManage: (g) => manageGroup(context, ref, g,
                      currentSelection:
                          widget.allowSaveAsGroup ? _selected : null),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: GenderFilterChips(
                value: _genderFilter,
                onChanged: (v) => setState(() => _genderFilter = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: AppColors.white, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l.searchMembers,
                  hintStyle:
                      const TextStyle(color: AppColors.grey, fontSize: 13),
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.grey, size: 20),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l.clearSearch,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close,
                              color: AppColors.grey, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
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
            Expanded(
              child: playersAsync.when(
                loading: () => const ListShimmer(),
                error: (e, _) =>
                    ErrorView(onRetry: () => ref.invalidate(playersProvider)),
                data: (players) {
                  final q = _query.trim().toLowerCase();
                  final inPool = players.where(_inPool).toList();
                  final filtered = inPool.where((p) {
                    final matchesGender =
                        _genderFilter == 'all' || p.gender == _genderFilter;
                    final matchesQuery =
                        q.isEmpty || p.name.toLowerCase().contains(q);
                    return matchesGender && matchesQuery;
                  }).toList();
                  if (filtered.isEmpty) {
                    // An empty pool and an empty search are different dead
                    // ends: the first means there is no one left to add.
                    return EmptyStateView(
                      icon: Icons.group_outlined,
                      title: inPool.isEmpty && players.isNotEmpty
                          ? l.allPlayersAlreadyAdded
                          : q.isEmpty
                              ? l.noPlayers
                              : l.noPlayersMatch,
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _MemberTile(
                      player: filtered[i],
                      selected: _selected.contains(filtered[i].uid),
                      onChanged: (checked) => setState(() {
                        if (checked) {
                          _selected.add(filtered[i].uid);
                        } else {
                          _selected.remove(filtered[i].uid);
                        }
                        _syncAppliedGroups(groups, validUids);
                      }),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    // Save the current selection as a reusable named group.
                    if (widget.allowSaveAsGroup && _selected.isNotEmpty) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => saveNewGroup(context, ref,
                              memberIds: _selected),
                          icon: const Icon(Icons.bookmark_add_outlined,
                              color: AppColors.gold, size: 18),
                          label: Text(
                            l.saveAsGroup,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.gold),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: const BorderSide(color: AppColors.gold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: BrandedButton(
                        label: widget.confirmLabel ?? l.done,
                        onPressed: () => Navigator.of(context).pop(_selected),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final PlayerSummary player;
  final bool selected;
  final ValueChanged<bool> onChanged;
  const _MemberTile({
    required this.player,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final initials = player.name.trim().isEmpty
        ? '?'
        : player.name
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();

    return CheckboxListTile(
      value: selected,
      onChanged: (v) => onChanged(v ?? false),
      activeColor: AppColors.gold,
      checkColor: AppColors.navyBlue,
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      secondary: CircleAvatar(
        radius: 20,
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
      title: Text(
        player.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }
}
