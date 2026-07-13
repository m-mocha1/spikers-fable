import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// The app's one avatar fallback (Premium Pass Phase 8): the photo when there
/// is one, otherwise gold initials on a gold-tinted navy disc. Every avatar —
/// profile hero ring, roster rows, coach cards — renders through this so the
/// fallback can never drift between screens again.
class AppAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;

  /// Radius of the photo/initials circle; rings, badges and halos are the
  /// caller's concern.
  final double radius;

  const AppAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final words = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    final initials = words.isEmpty
        ? '?'
        : words.map((w) => w[0]).take(2).join().toUpperCase();
    return CircleAvatar(
      radius: radius,
      // Translucent gold over the navy surface behind it — reads as a warm
      // navy disc (not an opaque gold one), keeping the initials in contrast.
      backgroundColor: AppColors.gold.withValues(alpha: 0.18),
      backgroundImage: hasPhoto ? CachedNetworkImageProvider(photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              initials,
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.67,
              ),
            ),
    );
  }
}
