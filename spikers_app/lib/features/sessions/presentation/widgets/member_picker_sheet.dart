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

/// Opens a modal bottom sheet that lets a coach pick members (players) for a
/// custom session. Returns the chosen uid set, or null if dismissed without
/// confirming. [initial] pre-selects members.
Future<Set<String>?> showMemberPicker(
  BuildContext context, {
  required Set<String> initial,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navyBlue,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _MemberPickerSheet(initial: initial),
  );
}

class _MemberPickerSheet extends ConsumerStatefulWidget {
  final Set<String> initial;
  const _MemberPickerSheet({required this.initial});

  @override
  ConsumerState<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends ConsumerState<_MemberPickerSheet> {
  final _searchController = TextEditingController();
  late final Set<String> _selected = {...widget.initial};
  String _query = '';
  String _genderFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final playersAsync = ref.watch(playersProvider);
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
                      l.chooseMembers,
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
                  final filtered = players.where((p) {
                    final matchesGender =
                        _genderFilter == 'all' || p.gender == _genderFilter;
                    final matchesQuery =
                        q.isEmpty || p.name.toLowerCase().contains(q);
                    return matchesGender && matchesQuery;
                  }).toList();
                  if (filtered.isEmpty) {
                    return EmptyStateView(
                      icon: Icons.group_outlined,
                      title: q.isEmpty ? l.noPlayers : l.noPlayersMatch,
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
                child: BrandedButton(
                  label: l.done,
                  onPressed: () => Navigator.of(context).pop(_selected),
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
