import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/app_avatar.dart';

/// Jersey colours for a token: a light-to-deep gradient.
class LineupPalette {
  final Color light;
  final Color deep;
  const LineupPalette(this.light, this.deep);

  static const teamA = LineupPalette(AppColors.teamA, AppColors.teamADeep);
  static const teamB = LineupPalette(AppColors.teamB, AppColors.teamBDeep);
  static const sub = LineupPalette(AppColors.teamSub, AppColors.teamSubDeep);
}

/// A player's circle on the line-up: a jersey-coloured disc showing [number]
/// (or the player's photo/initials when [number] is null, e.g. in the pool)
/// with a small name tag underneath. When [canEdit], a long-press lifts it
/// for drag-and-drop (drag data is the uid) and a tap selects it.
class LineupPlayerToken extends StatelessWidget {
  final String uid;
  final String name;
  final String? photoUrl;
  final String? number;
  final LineupPalette palette;
  final double radius;
  final bool selected;
  final bool canEdit;
  final VoidCallback? onTap;

  /// Puts the name tag above the disc instead of below — Team A faces the
  /// net from the far side, so its tags point away from the net too.
  final bool tagAbove;

  /// Uses the slim [LineupNameTag] (tight spaces such as the preview card).
  final bool dense;

  const LineupPlayerToken({
    super.key,
    required this.uid,
    required this.name,
    this.photoUrl,
    this.number,
    this.palette = LineupPalette.teamA,
    required this.radius,
    this.selected = false,
    this.canEdit = false,
    this.onTap,
    this.tagAbove = false,
    this.dense = false,
  });

  /// Total width a token occupies (disc plus room for the name tag).
  static double widthFor(double radius) => radius * 2 + 30;

  @override
  Widget build(BuildContext context) {
    final token = _body(selected: selected);
    if (!canEdit) return token;

    return LongPressDraggable<String>(
      data: uid,
      delay: const Duration(milliseconds: 150),
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.15, child: _body(selected: true)),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: token),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: token,
      ),
    );
  }

  Widget _body({required bool selected}) {
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    final avatar = DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.navyBlue,
      ),
      child: AppAvatar(
        name: name,
        photoUrl: photoUrl,
        radius: number == null ? radius : radius - 3,
      ),
    );
    // On court/bench the photo sits inside a team-coloured ring, with the
    // position number as a small badge on the rim.
    final disc = number == null
        ? avatar
        : Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [palette.light, palette.deep],
                  ),
                ),
                child: avatar,
              ),
              Positioned(
                right: -radius * 0.22,
                bottom: -radius * 0.18,
                child: _NumberBadge(
                  number: number!,
                  palette: palette,
                  size: radius * 0.88,
                ),
              ),
            ],
          );

    return SizedBox(
      width: widthFor(radius),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tagAbove) ...[
            LineupNameTag(text: firstName, dense: dense),
            const SizedBox(height: 4),
          ],
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.gold : AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? AppColors.gold.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.35),
                  blurRadius: selected ? 14 : 6,
                  offset: selected ? Offset.zero : const Offset(0, 3),
                ),
              ],
            ),
            child: disc,
          ),
          if (!tagAbove) ...[
            const SizedBox(height: 4),
            LineupNameTag(text: firstName, dense: dense),
          ],
        ],
      ),
    );
  }
}

/// Position number shown on the rim of a placed player's photo.
class _NumberBadge extends StatelessWidget {
  final String number;
  final LineupPalette palette;
  final double size;

  const _NumberBadge({
    required this.number,
    required this.palette,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.light, palette.deep],
        ),
        border: Border.all(color: AppColors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        number,
        style: TextStyle(
          color: AppColors.white,
          fontSize: size * 0.52,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

/// The small dark label under a token. [dense] is a slimmer variant for
/// tight layouts such as the session-screen preview card.
class LineupNameTag extends StatelessWidget {
  final String text;
  final bool dense;
  const LineupNameTag({super.key, required this.text, this.dense = false});

  static const height = 18.0;
  static const denseHeight = 14.0;

  static double heightFor({required bool dense}) =>
      dense ? denseHeight : height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: heightFor(dense: dense),
      constraints: BoxConstraints(minWidth: dense ? 22 : 28),
      padding: dense
          ? const EdgeInsets.fromLTRB(4, 1.5, 4, 0)
          : const EdgeInsets.fromLTRB(6, 2.5, 6, 0),
      decoration: BoxDecoration(
        color: AppColors.navyDeep.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.white,
          fontSize: dense ? 9 : 10.5,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
