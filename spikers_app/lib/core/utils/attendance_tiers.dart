/// Attendance milestone tiers (pure — trivially unit-testable).
///
/// Tier boundaries by lifetime games attended:
///   0–4   → tier 0 (Rookie)
///   5–19  → tier 1 (Regular)
///   20–49 → tier 2 (Veteran)
///   50+   → tier 3 (Legend)
///
/// Presentation maps tier indices to localized labels; this file owns only the
/// thresholds so the profile card and the milestone celebration can't drift
/// apart.
class AttendanceTiers {
  AttendanceTiers._();

  /// Games needed to *enter* tiers 1..3 (tier 0 starts at zero).
  static const thresholds = [5, 20, 50];

  /// Tier index (0..3) for a lifetime attendance [count].
  static int tierIndex(int count) {
    var tier = 0;
    for (final t in thresholds) {
      if (count >= t) tier++;
    }
    return tier;
  }

  /// The tier newly reached going from [previous] to [current] games, or null
  /// when no boundary was crossed (including when the count went down, e.g. a
  /// coach un-marking attendance).
  static int? crossedTier(int previous, int current) {
    if (current <= previous) return null;
    final from = tierIndex(previous);
    final to = tierIndex(current);
    return to > from ? to : null;
  }
}
