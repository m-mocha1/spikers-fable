import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/players_providers.dart';

/// Shows the mark-paid / mark-unpaid confirmation dialog and, on confirm,
/// flips the player's payment status through the players repository.
///
/// Passing the current [paidUntil] lets the dialog flip between the two
/// actions (paid -> unpaid and vice versa).
Future<void> confirmTogglePayment(
  BuildContext context,
  WidgetRef ref, {
  required String uid,
  required String name,
  required DateTime? paidUntil,
  bool isLifetime = false,
}) async {
  final l = AppLocalizations.of(context)!;
  if (isLifetime) {
    showAppSnackbar(l.lifetimeMember);
    return;
  }
  final paidNow = paidUntil != null && paidUntil.isAfter(DateTime.now());
  final markingPaid = !paidNow;
  final actionColor = markingPaid ? AppColors.success : AppColors.errorRed;
  final actionIcon = markingPaid
      ? Icons.check_circle_outline
      : Icons.highlight_off_rounded;
  final actionLabel = markingPaid ? l.paid : l.unpaid;
  final message =
      markingPaid ? l.confirmMarkPaid(name) : l.confirmMarkUnpaid(name);

  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => Dialog(
      backgroundColor: AppColors.navyLight,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: actionColor.withValues(alpha: 0.15),
                border: Border.all(color: actionColor, width: 2),
              ),
              child: Icon(actionIcon, color: actionColor, size: 36),
            ),
            const SizedBox(height: 14),
            Text(
              actionLabel,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.grey, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l.no,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l.yes,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (confirmed != true) return;

  final coach = ref.read(currentUserProvider).value;
  if (coach == null) return;
  final repo = ref.read(playersRepositoryProvider);
  try {
    if (paidNow) {
      await repo.markUnpaid(uid, coachUid: coach.uid, coachName: coach.name);
    } else {
      await repo.markPaid(uid, coachUid: coach.uid, coachName: coach.name);
    }
  } catch (_) {
    showAppSnackbar(l.unknownError);
  }
}
