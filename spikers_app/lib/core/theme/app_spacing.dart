/// Spacing and corner-radius design tokens (Premium Pass Phase 0).
///
/// The steps below are the values already dominant across the app's screens —
/// use these instead of raw numbers so padding and rounding stay consistent.
library;

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii by component role, matching the silhouettes already in use.
class AppRadius {
  /// Buttons, text fields, snack bars, small tiles.
  static const double control = 12;

  /// Cards and elevated containers.
  static const double card = 16;

  /// Pills, chips and selector segments.
  static const double chip = 20;

  /// Modal bottom sheets (top corners).
  static const double sheet = 20;
}
