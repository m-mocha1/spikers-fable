import 'package:flutter/animation.dart';

/// Centralized motion tokens — durations, curves, and stagger timing.
///
/// Every animation in the app pulls its timing from here instead of hardcoding
/// `Duration(milliseconds: ...)` / `Curves.*` inline, so the motion language
/// stays consistent and is tunable from one place (mirrors how spacing/colors
/// live in the theme system).
class AppMotion {
  AppMotion._();

  // ── Durations ──────────────────────────────────────────────────────────
  /// Micro-interactions: button/card press feedback, icon swaps.
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard entrance / transition for a single element.
  static const Duration normal = Duration(milliseconds: 350);

  /// Slower, more deliberate hero / splash / header reveals.
  static const Duration slow = Duration(milliseconds: 600);

  /// Looping ambient motion (pulsing live badge, shimmering highlight).
  static const Duration pulse = Duration(milliseconds: 1100);

  // ── Stagger ────────────────────────────────────────────────────────────
  /// Delay added per list item so rows cascade in instead of popping at once.
  static const Duration stagger = Duration(milliseconds: 60);

  /// Caps the cumulative stagger delay so long lists don't animate forever.
  static const int maxStaggerItems = 12;

  // ── Curves ─────────────────────────────────────────────────────────────
  /// Default easing for entrances — gentle, slightly overshooting settle.
  static const Curve enter = Curves.easeOutCubic;

  /// Easing for press-down / scale feedback.
  static const Curve press = Curves.easeOut;

  /// Easing for looping ambient motion.
  static const Curve ambient = Curves.easeInOut;

  /// Resolves the entrance delay for the item at [index] in a list, clamped
  /// to [maxStaggerItems] so deep scroll positions don't accrue huge delays.
  static Duration staggerFor(int index) {
    final capped = index < maxStaggerItems ? index : maxStaggerItems;
    return stagger * capped;
  }
}
