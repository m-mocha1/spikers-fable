import 'package:flutter/material.dart';

import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import '../constants/app_colors.dart';
import 'animations.dart';
import 'ringed_avatar.dart';

/// Large ringed profile avatar with an editing affordance: a camera hint badge
/// and, while [isUploading], a dimming overlay + spinner. When [onTap] is null
/// the avatar is display-only (no camera hint, not tappable).
///
/// Shared by the profile tab (a user editing their own photo) and the coach
/// player-profile screen (a coach editing a player's photo) so the two look
/// and behave identically.
class ProfileHeroAvatar extends StatelessWidget {
  final UserModel user;
  final String? badgeAsset;
  final String? badgeLabel;
  final bool isUploading;

  /// Null → display-only (no camera hint, not tappable).
  final VoidCallback? onTap;

  const ProfileHeroAvatar({
    super.key,
    required this.user,
    this.badgeAsset,
    this.badgeLabel,
    this.isUploading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: isUploading ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RingedAvatar(
            name: user.name,
            photoUrl: user.photoUrl,
            radius: 64,
            badgeAsset: badgeAsset,
            badgeLabel: badgeLabel,
          ),
          if (isUploading)
            // 140 = inner avatar (128) + ring and gap padding (2 × 6).
            Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.gold,
                ),
              ),
            ),
          if (!isUploading && onTap != null)
            PositionedDirectional(
              bottom: 2,
              start: 2,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.navyLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navyBlue, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 14,
                  color: AppColors.gold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
