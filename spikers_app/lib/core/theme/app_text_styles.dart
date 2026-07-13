import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Shared micro text styles (Premium Pass Phase 0).
///
/// These deliberately omit a font family so they inherit Cairo from the
/// ambient [DefaultTextStyle], exactly like the inline styles they replace.
/// Pair with an upper-cased string (`text.toUpperCase()`).
class AppTextStyles {
  /// Amber all-caps eyebrow — the small gold label that sits above a hero
  /// block or names a metric (e.g. "UPCOMING", "NEXT UP").
  static const eyebrow = TextStyle(
    color: AppColors.gold,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
  );

  /// Grey all-caps section header — quiet list/section labels inside cards.
  /// 11sp minimum and moderated letter-spacing per the App Store audit
  /// (micro caps below 11sp were flagged as unreadable).
  static const sectionHeader = TextStyle(
    color: AppColors.grey,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
  );
}
