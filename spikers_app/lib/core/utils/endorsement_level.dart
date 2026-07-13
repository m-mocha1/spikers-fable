/// Endorsement level (1–5) derived purely from the lifetime endorsement
/// count. There is intentionally no decay — the level only ever climbs, so it
/// reads as a "trusted veteran" badge rather than a recent-behaviour signal.
///
/// Thresholds are deliberately simple and centralised here so the session
/// list, attendee list, and profile all agree. Tune the boundaries in one
/// place.
///
/// Lifetime endorsements needed to *enter* levels 2..5 (level 1 starts at
/// zero) — the endorsement twin of `AttendanceTiers.thresholds`, exposed so
/// the profile's progress bar and badge case can render the ladder.
const endorsementThresholds = [40, 100, 200, 400];

int endorsementLevel(int endorsementCount) {
  var level = 1;
  for (final t in endorsementThresholds) {
    if (endorsementCount >= t) level++;
  }
  return level;
}

/// The endorsement level newly reached going from [previous] to [current]
/// lifetime endorsements, or null when no boundary was crossed (including when
/// the count didn't rise). Mirrors `AttendanceTiers.crossedTier` so the profile
/// can fire a one-shot promotion celebration.
int? crossedEndorsementLevel(int previous, int current) {
  if (current <= previous) return null;
  final from = endorsementLevel(previous);
  final to = endorsementLevel(current);
  return to > from ? to : null;
}
