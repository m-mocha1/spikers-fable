import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/animations.dart';

/// Admin-only session-card chooser used while testing new art. Shows a
/// [randomLabel] tile followed by every design in `AppAssets.cardDesigns`,
/// numbered 1..N (card 1 is index 0). [value] is the 0-based design index, or
/// null for the default random pick.
class SessionArtPicker extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  /// Label for the "let the app pick" tile.
  final String randomLabel;

  /// Screen-reader label for card [number] (1-based).
  final String Function(int number) cardSemanticLabel;

  const SessionArtPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.randomLabel,
    required this.cardSemanticLabel,
  });

  static const double _tileWidth = 104;
  static const double _tileHeight = 68;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _randomTile(),
        for (var i = 0; i < AppAssets.cardDesigns.length; i++) _cardTile(i),
      ],
    );
  }

  Widget _shell({
    required bool selected,
    required String semanticsLabel,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: _tileWidth,
          height: _tileHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.navyLight,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.navyElevated,
              width: selected ? 2 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _randomTile() {
    final selected = value == null;
    return _shell(
      selected: selected,
      semanticsLabel: randomLabel,
      onTap: () => onChanged(null),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shuffle_rounded,
            size: 20,
            color: selected ? AppColors.gold : AppColors.grey,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            randomLabel,
            style: TextStyle(
              color: selected ? AppColors.gold : AppColors.grey,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardTile(int index) {
    final selected = value == index;
    final number = index + 1;
    return _shell(
      selected: selected,
      semanticsLabel: cardSemanticLabel(number),
      onTap: () => onChanged(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.cardDesigns[index], fit: BoxFit.cover),
          // Number badge so the tester can recall a card by its number.
          PositionedDirectional(
            top: 4,
            start: 4,
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.navyBlue.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$number',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (selected)
            const PositionedDirectional(
              bottom: 4,
              end: 4,
              child: Icon(Icons.check_circle_rounded,
                  size: 18, color: AppColors.gold),
            ),
        ],
      ),
    );
  }
}
