import 'package:flutter/material.dart';

class AppColors {
  static const navyBlue  = Color(0xFF0D1B3E);
  static const navyLight = Color(0xFF1A2D5A);
  static const gold      = Color(0xFFFFB700);
  static const white     = Color(0xFFFFFFFF);
  static const grey      = Color(0xFF9E9E9E);
  static const errorRed  = Color(0xFFE53935);
  static const success   = Color(0xFF43A047);
  static const warning   = Color(0xFFFB8C00);

  // ── Tonal shades (depth only, not new brand accents) ──────────────────────
  /// Darker navy for gradient bottoms / scaffold depth.
  static const navyDeep     = Color(0xFF081026);
  /// One step lighter than [navyLight] for layered / elevated cards.
  static const navyElevated = Color(0xFF22376B);
  /// Warm end of the gold gradient — still reads as gold, adds richness.
  static const goldAmber    = Color(0xFFFF9500);
}
