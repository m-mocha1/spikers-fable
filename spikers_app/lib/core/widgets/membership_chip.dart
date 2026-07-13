import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_gradients.dart';
import '../constants/app_motion.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_spacing.dart';

/// The app's one membership-status chip (Premium Pass Phase 6): identical
/// pill geometry everywhere, with colour carrying the state — green outline
/// while active, amber outline with a "Nd left" second line when expiring,
/// red outline when unpaid, and the solid gold-gradient treatment reserved
/// for lifetime members.
///
/// Used by the coach roster (tappable, toggles payment) and the player's own
/// profile (read-only). [emphasized] adds the gold glow to the lifetime state
/// — only the roster passes it, keeping the app's one-glow-per-screen budget.
class MembershipChip extends StatelessWidget {
  final bool isPaid;
  final int daysLeft;
  final bool isLifetime;

  /// Lifetime chips glow only where they're the screen's single glowing
  /// element (the Players roster).
  final bool emphasized;

  /// Non-null makes the chip tappable (coach roster toggles payment) with a
  /// ripple and a ≥44px hit area around the pill.
  final VoidCallback? onTap;

  const MembershipChip({
    super.key,
    required this.isPaid,
    required this.daysLeft,
    required this.isLifetime,
    this.emphasized = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final Color color;
    final IconData icon;
    if (isLifetime) {
      color = AppColors.gold;
      icon = Icons.workspace_premium;
    } else if (!isPaid || daysLeft == 0) {
      color = AppColors.errorRed;
      icon = Icons.error_outline;
    } else if (daysLeft <= 9) {
      color = AppColors.warning;
      icon = Icons.schedule;
    } else {
      color = AppColors.success;
      icon = Icons.check_circle_outline;
    }
    final showDays = !isLifetime && isPaid && daysLeft > 0 && daysLeft <= 9;
    final fg = isLifetime ? AppColors.navyBlue : color;
    final label = isLifetime ? l.lifetime : (isPaid ? l.paid : l.unpaid);

    final chip = AnimatedContainer(
      duration: AppMotion.fast,
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 2,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        gradient: isLifetime ? AppGradients.goldCta : null,
        color: isLifetime ? null : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: isLifetime ? null : Border.all(color: color),
        boxShadow: isLifetime && emphasized
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  blurRadius: 10,
                ),
              ]
            : const [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
              if (showDays)
                Text(
                  l.daysLeft(daysLeft),
                  style: TextStyle(color: fg, fontSize: 10.5),
                ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip + 4),
        child: Padding(padding: const EdgeInsets.all(4), child: chip),
      ),
    );
  }
}
