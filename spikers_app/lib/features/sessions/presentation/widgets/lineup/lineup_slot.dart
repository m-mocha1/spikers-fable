import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../domain/repositories/sessions_repository.dart';
import 'lineup_player_token.dart';

/// One spot on a team's court or the bench. Shows the placed player's token,
/// or an empty outlined circle labelled [number]. When [canEdit], it accepts
/// dropped players and taps (for tap-to-swap).
class LineupSlotView extends StatelessWidget {
  final String? uid;
  final PublicProfile? profile;
  final String number;
  final LineupPalette palette;
  final double radius;
  final bool canEdit;
  final bool selected;

  /// Name tag above the disc (Team A) instead of below.
  final bool tagAbove;

  /// Slim name tag (see [LineupNameTag.dense]).
  final bool dense;

  /// Called when a dragged player (uid) is dropped here.
  final ValueChanged<String> onDrop;

  /// Called when the slot (empty or occupied) is tapped.
  final VoidCallback onTap;

  const LineupSlotView({
    super.key,
    required this.uid,
    required this.profile,
    required this.number,
    required this.palette,
    required this.radius,
    required this.canEdit,
    required this.selected,
    this.tagAbove = false,
    this.dense = false,
    required this.onDrop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => canEdit && d.data != uid,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        final placed = uid;
        final Widget child = placed == null
            ? _EmptySpot(
                key: const ValueKey('empty'),
                number: number,
                palette: palette,
                radius: radius,
                highlight: hovering,
                tagAbove: tagAbove,
                dense: dense,
              )
            : LineupPlayerToken(
                key: ValueKey(placed),
                uid: placed,
                name: profile?.name ?? '',
                photoUrl: profile?.photoUrl,
                number: number,
                palette: palette,
                radius: radius,
                selected: selected || hovering,
                canEdit: canEdit,
                onTap: onTap,
                tagAbove: tagAbove,
                dense: dense,
              );
        final animated = AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: a, child: c),
          ),
          child: child,
        );
        if (placed != null || !canEdit) return animated;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: animated,
        );
      },
    );
  }
}

class _EmptySpot extends StatelessWidget {
  final String number;
  final LineupPalette palette;
  final double radius;
  final bool highlight;
  final bool tagAbove;
  final bool dense;

  const _EmptySpot({
    super.key,
    required this.number,
    required this.palette,
    required this.radius,
    required this.highlight,
    required this.tagAbove,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final edge = highlight ? AppColors.gold : AppColors.white;
    // Keeps empty and filled spots the same height (name tag line).
    final tagSpace =
        SizedBox(height: 4 + LineupNameTag.heightFor(dense: dense));
    return SizedBox(
      width: LineupPlayerToken.widthFor(radius),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tagAbove) tagSpace,
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: radius * 2 + 5,
            height: radius * 2 + 5,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Neutral dark glass + a solid team-coloured ring: a translucent
              // blue tint over the orange court muddies to mauve.
              color: highlight
                  ? AppColors.gold.withValues(alpha: 0.4)
                  : AppColors.navyDeep.withValues(alpha: 0.28),
              border: Border.all(
                color: highlight ? AppColors.gold : palette.light,
                width: 2.5,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Text(
              number,
              style: TextStyle(
                color: edge.withValues(alpha: highlight ? 1 : 0.85),
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (!tagAbove) tagSpace,
        ],
      ),
    );
  }
}
