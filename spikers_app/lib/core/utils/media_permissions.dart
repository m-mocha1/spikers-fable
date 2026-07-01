import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/app_localizations.dart';
import '../constants/app_colors.dart';
import 'app_snackbar.dart';

/// Camera permission gate used before launching the image picker's camera path.
///
/// Requests the OS permission first and only returns true when access is
/// granted. On a plain denial it shows a snackbar; when the permission is
/// permanently denied it shows a dialog that can deep-link to the app's system
/// settings. This is what lets the app comply with the platform requirement to
/// ask before touching the camera and to fail gracefully instead of silently
/// when denied.
///
/// Gallery selection intentionally has no equivalent gate: it goes through the
/// Android Photo Picker / iOS PHPicker, which require no media permission.

/// Returns true only if camera access is available.
Future<bool> ensureCameraPermission(
        BuildContext context, AppLocalizations l) =>
    _ensure(
      context,
      l,
      permission: Permission.camera,
      title: l.cameraPermissionTitle,
      message: l.cameraPermissionMessage,
    );

Future<bool> _ensure(
  BuildContext context,
  AppLocalizations l, {
  required Permission permission,
  required String title,
  required String message,
}) async {
  var status = await permission.status;
  if (status.isGranted || status.isLimited) return true;

  // Ask the OS. The system prompt only appears the first time; afterwards this
  // returns the prior decision (denied / permanently denied / restricted).
  status = await permission.request();
  if (status.isGranted || status.isLimited) return true;

  if (!context.mounted) return false;

  if (status.isPermanentlyDenied || status.isRestricted) {
    await _showPermissionSettingsDialog(context, l, title: title, message: message);
  } else {
    showAppSnackbar(l.permissionDenied);
  }
  return false;
}

/// Navy/gold styled dialog modeled on [showDeleteConfirm], offering a path to
/// the system settings when a permission has been permanently denied.
Future<void> _showPermissionSettingsDialog(
  BuildContext context,
  AppLocalizations l, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (dialogContext) => Dialog(
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
                color: AppColors.gold.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.gold, width: 2),
              ),
              child: const Icon(Icons.lock_outline,
                  color: AppColors.gold, size: 36),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
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
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l.cancel,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      openAppSettings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.navyBlue,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l.openSettings,
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
}
