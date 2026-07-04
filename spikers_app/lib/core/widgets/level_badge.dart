import 'package:flutter/material.dart';

/// Renders a progression badge PNG (games-played tier / endorsement level) at a
/// fixed square size.
///
/// If the asset can't be loaded — e.g. an image was renamed or not added yet —
/// it degrades to [fallback] (or nothing) instead of crashing the card, so the
/// UI stays resilient to missing art. The [label] is surfaced as a tooltip and
/// semantic description so the tier name is still accessible without the pill.
class LevelBadge extends StatelessWidget {
  final String asset;
  final double size;
  final String? label;
  final Widget? fallback;

  const LevelBadge({
    super.key,
    required this.asset,
    this.size = 48,
    this.label,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: label,
      errorBuilder: (_, _, _) => fallback ?? const SizedBox.shrink(),
    );
    if (label == null) return image;
    return Tooltip(message: label!, child: image);
  }
}
