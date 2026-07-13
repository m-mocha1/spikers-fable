import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_motion.dart';
import '../theme/app_spacing.dart';
import 'animations.dart';

/// One selectable option in an [AppChoiceChips] group.
class AppChoiceChipOption<T> {
  final T value;

  /// Visible chip text — also what screen readers announce when [iconOnly].
  final String label;
  final IconData? icon;

  /// Render only [icon] to keep dense filter rows compact; [label] still
  /// names the chip for screen readers, so it is never truly unlabeled.
  final bool iconOnly;

  const AppChoiceChipOption({
    required this.value,
    required this.label,
    this.icon,
    this.iconOnly = false,
  }) : assert(icon != null || !iconOnly, 'iconOnly requires an icon');
}

/// The app's single-choice selector (Premium Pass Phase 3). One silhouette
/// for every chooser — list filters, gender/audience pickers, the leaderboard
/// period toggle — replacing the previous mix of segmented controls and
/// per-screen chip widgets.
///
/// [onSelected] fires with the tapped value even when it is already selected,
/// so optional fields can implement tap-again-to-clear (Register's gender).
///
/// Needs bounded width (labels ellipsize via `Flexible`): inside a plain
/// [Row], wrap it in an `Expanded`.
class AppChoiceChips<T> extends StatelessWidget {
  final List<AppChoiceChipOption<T>> options;

  /// Currently selected value; null selects nothing.
  final T? value;
  final ValueChanged<T> onSelected;

  /// When true the chips split the available width equally (form selectors);
  /// when false each chip hugs its content and the group wraps (filters).
  final bool expanded;

  /// Idle fill override for chips sitting on a navyLight surface (dialogs).
  final Color? fillColor;

  /// Nav-bar-style filter look: no pill fill or outline at all — the chips
  /// share the screen's background and only the icon/label flips color (gold
  /// when selected, grey when idle). For list filter rows; form selectors
  /// keep the filled pill.
  final bool quiet;

  const AppChoiceChips({
    super.key,
    required this.options,
    required this.value,
    required this.onSelected,
    this.expanded = false,
    this.fillColor,
    this.quiet = false,
  });

  @override
  Widget build(BuildContext context) {
    if (expanded) {
      return Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: _chip(options[i])),
          ],
        ],
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [for (final option in options) _chip(option)],
    );
  }

  Widget _chip(AppChoiceChipOption<T> option) {
    return AppChoiceChip(
      label: option.label,
      icon: option.icon,
      iconOnly: option.iconOnly,
      selected: option.value == value,
      fillColor: fillColor,
      quiet: quiet,
      onTap: () => onSelected(option.value),
    );
  }
}

/// The one gold-on-navy selector pill used app-wide: gold fill when selected,
/// navy fill + grey outline when idle, always [height] tall. The [quiet]
/// variant drops the pill entirely (nav-bar style: only the icon/label color
/// flips). Prefer [AppChoiceChips] for single-choice groups; use this
/// directly only for multi-select sets (the coach picker).
class AppChoiceChip extends StatelessWidget {
  /// Single fixed chip height app-wide — the App Store audit flagged the
  /// assorted selector heights; 40dp also keeps the tap target comfortable.
  static const double height = 40;

  static const double _iconSize = 18;

  final String label;
  final IconData? icon;
  final bool iconOnly;
  final bool selected;
  final Color? fillColor;

  /// See [AppChoiceChips.quiet].
  final bool quiet;

  final VoidCallback onTap;

  const AppChoiceChip({
    super.key,
    required this.label,
    this.icon,
    this.iconOnly = false,
    required this.selected,
    this.fillColor,
    this.quiet = false,
    required this.onTap,
  }) : assert(icon != null || !iconOnly, 'iconOnly requires an icon');

  @override
  Widget build(BuildContext context) {
    // Quiet chips signal selection like the nav bar: gold vs grey content on
    // the screen's own background. Filled chips flip navy-on-gold.
    final foreground = quiet
        ? (selected ? AppColors.gold : AppColors.grey)
        : (selected ? AppColors.navyBlue : AppColors.white);
    return Semantics(
      button: true,
      selected: selected,
      label: iconOnly ? label : null,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: height,
          // Quiet chips have no pill to fill — tighter padding keeps dense
          // filter rows (leaderboard, players) on one line at 360dp.
          padding: EdgeInsets.symmetric(
              horizontal: quiet ? AppSpacing.md : AppSpacing.lg),
          decoration: BoxDecoration(
            color: quiet
                ? Colors.transparent
                : selected
                    ? AppColors.gold
                    : fillColor ?? AppColors.navyLight,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            border: quiet
                ? null
                : Border.all(
                    color: selected ? AppColors.gold : AppColors.grey),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) Icon(icon, color: foreground, size: _iconSize),
              if (icon != null && !iconOnly)
                const SizedBox(width: AppSpacing.xs),
              if (!iconOnly)
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
