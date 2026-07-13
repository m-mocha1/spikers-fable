import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'app_choice_chips.dart';

/// The All / male / female pill row used to filter gender-tagged lists
/// (players tab, sessions history, leaderboard, member picker). Thin wrapper
/// over [AppChoiceChips]; [value] is 'all', 'male' or 'female'.
class GenderFilterChips extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  /// All-icon mode for rows shared with other controls (the leaderboard's
  /// period toggle): "All" renders as a groups icon instead of text, giving
  /// the group a fixed, locale-independent width. Every chip keeps its
  /// localized semantic label. Also safe un-flexed inside a plain [Row] —
  /// icon-only chips don't need the bounded width text chips do.
  final bool compact;

  const GenderFilterChips({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AppChoiceChips<String>(
      value: value,
      onSelected: onChanged,
      // Nav-bar-style: no pill fill, the active filter is the gold one.
      quiet: true,
      options: [
        AppChoiceChipOption(
          value: 'all',
          label: l.allGenders,
          icon: compact ? Icons.groups : null,
          iconOnly: compact,
        ),
        // Icon-only keeps the filter rows compact; the localized label is
        // still announced by screen readers.
        AppChoiceChipOption(
          value: 'male',
          label: l.male,
          icon: Icons.male,
          iconOnly: true,
        ),
        AppChoiceChipOption(
          value: 'female',
          label: l.female,
          icon: Icons.female,
          iconOnly: true,
        ),
      ],
    );
  }
}
