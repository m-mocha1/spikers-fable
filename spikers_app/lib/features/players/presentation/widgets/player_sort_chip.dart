import 'package:flutter/material.dart';

import '../../../../core/widgets/app_choice_chips.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/player_summary.dart';

/// Roster ordering for the players tab. [name] is the datasource's own A–Z
/// order — the default, and the state the chip cycles back to.
enum PlayerSort {
  name,
  activeFirst,
  inactiveFirst;

  /// One tap forward: off → active first → inactive first → off.
  PlayerSort get next => switch (this) {
        PlayerSort.name => PlayerSort.activeFirst,
        PlayerSort.activeFirst => PlayerSort.inactiveFirst,
        PlayerSort.inactiveFirst => PlayerSort.name,
      };

  bool get isApplied => this != PlayerSort.name;

  /// Groups by membership state ([PlayerSummary.isPaid] — lifetime members and
  /// unexpired ones are "active"), keeping the A–Z order inside each group.
  /// The name tiebreak is explicit because `List.sort` is not stable.
  List<PlayerSummary> apply(List<PlayerSummary> players) {
    if (!isApplied) return players;
    return [...players]..sort((a, b) {
        if (a.isPaid != b.isPaid) {
          final aFirst = this == PlayerSort.activeFirst ? a.isPaid : !a.isPaid;
          return aFirst ? -1 : 1;
        }
        // Same comparator the datasource sorts the roster with.
        return a.name.compareTo(b.name);
      });
  }
}

/// Cycles the roster's membership sort. Same silhouette as the gender filter
/// next to it — a quiet, icon-only [AppChoiceChip] that turns gold once a sort
/// is applied. The icon carries the direction (⇅ off, ↑ active first, ↓
/// inactive first) and the localized label names the chip for screen readers.
class PlayerSortChip extends StatelessWidget {
  final PlayerSort value;
  final ValueChanged<PlayerSort> onChanged;

  const PlayerSortChip({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final (IconData icon, String label) = switch (value) {
      PlayerSort.name => (Icons.swap_vert, l.sortByMembership),
      PlayerSort.activeFirst => (Icons.arrow_upward, l.sortActiveFirst),
      PlayerSort.inactiveFirst => (Icons.arrow_downward, l.sortInactiveFirst),
    };
    return AppChoiceChip(
      label: label,
      icon: icon,
      iconOnly: true,
      quiet: true,
      selected: value.isApplied,
      onTap: () => onChanged(value.next),
    );
  }
}
