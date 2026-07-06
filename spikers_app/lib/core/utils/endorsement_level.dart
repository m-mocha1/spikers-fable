/// Endorsement level (1–5) derived purely from the lifetime endorsement
/// count. There is intentionally no decay — the level only ever climbs, so it
/// reads as a "trusted veteran" badge rather than a recent-behaviour signal.
///
/// Thresholds are deliberately simple and centralised here so the session
/// list, attendee list, and profile all agree. Tune the boundaries in one
/// place.
int endorsementLevel(int endorsementCount) {
  if (endorsementCount >= 400) return 5;
  if (endorsementCount >= 200) return 4;
  if (endorsementCount >= 100) return 3;
  if (endorsementCount >= 40) return 2;
  return 1;
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
