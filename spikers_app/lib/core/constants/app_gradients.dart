import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized gradient tokens — the app stays strictly navy + gold, so these
/// are all built from tonal shades of the existing brand colors (see
/// [AppColors]). Screens compose these instead of hand-rolling `LinearGradient`
/// inline, mirroring how colors/spacing/motion live in one place.
class AppGradients {
  AppGradients._();

  /// Subtle vertical scaffold backdrop: navy at the top settling into a deeper
  /// navy at the bottom. Low contrast on purpose so text legibility is
  /// unchanged from the old flat background.
  static const scaffoldBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.navyBlue, AppColors.navyDeep],
  );

  /// Gold call-to-action / spotlight fill — gold warming into amber.
  static const goldCta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gold, AppColors.goldAmber],
  );

  /// Bottom-up scrim laid over card background images so overlaid text always
  /// has enough contrast regardless of the underlying artwork. Kept light —
  /// the card designs are navy-toned already, so this is a veil, not a cover.
  static const cardScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0x990D1B3E), Color(0x4D0D1B3E), Color(0x260D1B3E)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Heavier variant of [cardScrim] for the Next-Up spotlight, whose text sits
  /// directly on the artwork with no card surface underneath.
  static const heroScrim = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xCC0D1B3E), Color(0x8C0D1B3E), Color(0x590D1B3E)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Faint diagonal light sheen laid on top of card artwork — a whisper of
  /// gloss that makes the surface read as printed/laminated rather than flat.
  static const cardSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x12FFFFFF), Color(0x00FFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.45, 1.0],
  );
}
