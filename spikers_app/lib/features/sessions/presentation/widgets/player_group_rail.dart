import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/player_group_model.dart';

/// Horizontal, wrapping rail of a coach's saved player groups plus an optional
/// trailing "New group" chip. Tapping a group toggles its members in/out of the
/// selection (combinable); a chip lights gold when its id is in
/// [appliedGroupIds] — i.e. the coach explicitly applied it. Long-press opens
/// the manage menu.
///
/// Shared between the create-session screen and the member picker so both apply
/// groups the same way.
class PlayerGroupRail extends StatelessWidget {
  final List<PlayerGroup> groups;

  /// Ids of the groups the coach has explicitly applied — the gold-highlight
  /// state. Tracked, not derived from the member set, so an overlapping group
  /// never lights up just because its members are covered.
  final Set<String> appliedGroupIds;

  final ValueChanged<PlayerGroup> onApply;
  final ValueChanged<PlayerGroup> onManage;

  /// Optional trailing "New group" chip; hidden when null.
  final VoidCallback? onNew;

  const PlayerGroupRail({
    super.key,
    required this.groups,
    required this.appliedGroupIds,
    required this.onApply,
    required this.onManage,
    this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final group in groups)
          PlayerGroupChip(
            label: group.name,
            memberCount: group.memberCount,
            applied: appliedGroupIds.contains(group.id),
            onTap: () => onApply(group),
            onLongPress: () => onManage(group),
          ),
        if (onNew != null)
          PlayerGroupChip.action(
            label: l.newGroup,
            icon: Icons.add,
            onTap: onNew!,
          ),
      ],
    );
  }
}

/// A single group pill. The default constructor is a toggleable saved group
/// (gold when [applied], with a member-count badge); [PlayerGroupChip.action]
/// is the dashed "New group" affordance.
class PlayerGroupChip extends StatelessWidget {
  static const double _height = 40;

  final String label;
  final int? memberCount;
  final bool applied;
  final IconData? icon;
  final bool isAction;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const PlayerGroupChip({
    super.key,
    required this.label,
    required this.memberCount,
    required this.applied,
    required this.onTap,
    this.onLongPress,
  })  : icon = null,
        isAction = false;

  const PlayerGroupChip.action({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  })  : memberCount = null,
        applied = false,
        isAction = true,
        onLongPress = null;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final foreground = applied ? AppColors.navyBlue : AppColors.white;

    final semanticLabel = memberCount == null
        ? label
        : '$label, ${l.groupMembersCount(memberCount!)}';

    return Semantics(
      button: true,
      selected: applied,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            height: _height,
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: applied ? AppColors.gold : AppColors.navyLight,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(
                color: applied ? AppColors.gold : AppColors.grey,
                // Dashed-look substitute: a lighter, thinner outline marks the
                // "New group" action chip as a create affordance vs a saved one.
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: AppColors.gold),
                  const SizedBox(width: AppSpacing.xs),
                ] else if (applied) ...[
                  const Icon(Icons.check, size: 16, color: AppColors.navyBlue),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: isAction ? AppColors.gold : foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (memberCount != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _CountBadge(count: memberCount!, applied: applied),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final bool applied;
  const _CountBadge({required this.count, required this.applied});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: applied
            ? AppColors.navyBlue.withValues(alpha: 0.18)
            : AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: applied ? AppColors.navyBlue : AppColors.gold,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
