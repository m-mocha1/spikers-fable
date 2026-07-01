import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// Small badge shown next to a player's name when they're flagged injured.
/// The flag is admin-set (see UserModel.injured); this widget only renders it.
/// Kept in one place so the icon, color, and label stay consistent everywhere.
class InjuredIcon extends StatelessWidget {
  final double size;
  const InjuredIcon({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Tooltip(
      message: l.injured,
      child: Icon(
        Icons.local_hospital,
        size: size,
        color: AppColors.errorRed,
      ),
    );
  }
}
