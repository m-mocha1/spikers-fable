import 'package:flutter/material.dart';

class AppColors {
  static const navyBlue  = Color(0xFF0D1B3E);
  static const navyLight = Color(0xFF1A2D5A);
  static const gold      = Color(0xFFFFB700);
  static const white     = Color(0xFFFFFFFF);
  static const grey      = Color(0xFF9E9E9E);
  static const errorRed  = Color(0xFFE53935);
  /// Softer, desaturated red for the "leave session" feedback burst — reads as
  /// red without the alarm brightness of [errorRed].
  static const redMuted  = Color(0xFFB44A46);
  static const success   = Color(0xFF43A047);
  static const warning   = Color(0xFFFB8C00);

  // ── Tonal shades (depth only, not new brand accents) ──────────────────────
  /// Darker navy for gradient bottoms / scaffold depth.
  static const navyDeep     = Color(0xFF081026);
  /// One step lighter than [navyLight] for layered / elevated cards.
  static const navyElevated = Color(0xFF22376B);
  /// Warm end of the gold gradient — still reads as gold, adds richness.
  static const goldAmber    = Color(0xFFFF9500);

  // ── Volleyball court (line-up screen) ─────────────────────────────────────
  /// Playing area of the court (light centre → darker edge gradient).
  static const courtSurface     = Color(0xFFE79A5C);
  static const courtSurfaceEdge = Color(0xFFD27A3C);
  /// Free zone / sideline around the court.
  static const courtFreeZone    = Color(0xFF1C5F6E);
  static const courtFreeZoneDeep = Color(0xFF123F4C);
  /// Team jersey colours: Team A blue, Team B orange, subs teal.
  static const teamA     = Color(0xFF2F6BE8);
  static const teamADeep = Color(0xFF1A3E9E);
  static const teamB     = Color(0xFFFF7A2E);
  static const teamBDeep = Color(0xFFC2410C);
  static const teamSub     = Color(0xFF1FA3A8);
  static const teamSubDeep = Color(0xFF0E6670);
}
