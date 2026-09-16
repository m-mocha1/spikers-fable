class AgeCalculator {
  /// Minimum age to hold an account. Must match `isValidDob` in
  /// firestore.rules, which rejects DOBs younger than this many years.
  static const int minimumAgeYears = 8;

  /// Latest date of birth the pickers may offer: exactly [minimumAgeYears]
  /// ago today. The rule counts 365-day years (no leap days), so a DOB on or
  /// before this date always passes it.
  static DateTime latestAllowedDob([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(n.year - minimumAgeYears, n.month, n.day);
  }

  static int fromDate(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }
}
