import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../constants/app_colors.dart';

/// The All / male / female pill row used to filter gender-tagged lists
/// (players tab, sessions history). [value] is 'all', 'male' or 'female'.
class GenderFilterChips extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const GenderFilterChips({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppFilterChip(
          label: l.allGenders,
          active: value == 'all',
          onTap: () => onChanged('all'),
        ),
        const SizedBox(width: 8),
        AppFilterChip(
          icon: Icons.male,
          active: value == 'male',
          onTap: () => onChanged('male'),
        ),
        const SizedBox(width: 8),
        AppFilterChip(
          icon: Icons.female,
          active: value == 'female',
          onTap: () => onChanged('female'),
        ),
      ],
    );
  }
}

/// Gold-on-navy pill used for the app's list filters (gender chips, the
/// leaderboard's month/all-time toggle). Provide [label] or [icon].
class AppFilterChip extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;
  const AppFilterChip({
    super.key,
    this.label,
    this.icon,
    required this.active,
    required this.onTap,
  }) : assert(label != null || icon != null);

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.navyBlue : AppColors.white;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.gold : AppColors.navyLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.gold : AppColors.grey),
        ),
        child: icon != null
            ? Icon(icon, color: color, size: 18)
            : Text(
                label!,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }
}
