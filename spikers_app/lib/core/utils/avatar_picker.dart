import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'media_permissions.dart';

/// Shows the gallery/camera bottom sheet, then picks and downscales an image
/// (512px, quality 80). Returns null if the user cancels the sheet, denies the
/// camera permission, or picks nothing.
///
/// Shared by the profile tab (a user editing their own photo) and the coach
/// player-profile screen (a coach editing another player's photo) so the pick
/// UX stays identical in both places.
Future<XFile?> pickAvatarImage(
  BuildContext context,
  AppLocalizations l,
) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.navyLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(
              Icons.photo_library_outlined,
              color: AppColors.gold,
            ),
            title: Text(l.pickFromGallery),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(
              Icons.camera_alt_outlined,
              color: AppColors.gold,
            ),
            title: Text(l.takePhoto),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return null;

  // Camera capture needs a runtime permission; gallery goes through the
  // Android Photo Picker / iOS PHPicker, which require none.
  if (source == ImageSource.camera) {
    if (!context.mounted) return null;
    final granted = await ensureCameraPermission(context, l);
    if (!granted) return null;
  }

  return ImagePicker().pickImage(
    source: source,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 80,
  );
}
