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

  /// Pause before content reveals beneath a landing hero image (session art
  /// flying card ↔ detail). Lets the artwork settle first so the text feels
  /// like it reveals itself rather than popping into existence.
  static const Duration heroSettle = Duration(milliseconds: 300);

  /// Vertical travel in *pixels* for hero-content reveals — a small upward
  /// drift (spec: 8–16px), unlike the fraction-based slides used elsewhere.
  static const double revealShift = 12;

  // ── Stagger ────────────────────────────────────────────────────────────
  /// Per-item interval for entrance cascades — used both by `flutter_animate`'s
  /// `.animate(interval: ...)` on static screen bodies (session detail, profile)
  /// and by [staggerFor] for live-stream list rows, so both reveal identically.
  static const Duration stagger = Duration(milliseconds: 60);

  /// Number of leading list rows that cascade in. Rows past this appear with no
  /// delay, so scrolling a long list never exposes a row still waiting its turn.
  static const int staggerLeadCount = 10;

  /// Entrance delay for the list row at [index]: the first [staggerLeadCount]
  /// rows cascade one after another; deeper rows get zero delay so they never
  /// lag behind a fast scroll.
  static Duration staggerFor(int index) =>
      index < staggerLeadCount ? stagger * index : Duration.zero;

  // ── Curves ─────────────────────────────────────────────────────────────
  /// Default easing for entrances — gentle, slightly overshooting settle.
  static const Curve enter = Curves.easeOutCubic;

  /// Easing for press-down / scale feedback.
  static const Curve press = Curves.easeOut;

  /// Easing for looping ambient motion.
  static const Curve ambient = Curves.easeInOut;
}
