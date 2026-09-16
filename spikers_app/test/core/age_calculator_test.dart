import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/core/utils/age_calculator.dart';

void main() {
  group('AgeCalculator.latestAllowedDob', () {
    test('is exactly minimumAgeYears ago on the same month/day', () {
      expect(AgeCalculator.latestAllowedDob(DateTime(2026, 9, 16)),
          DateTime(2018, 9, 16));
    });

    test('someone born on that date is exactly minimumAgeYears old', () {
      expect(AgeCalculator.fromDate(AgeCalculator.latestAllowedDob()),
          AgeCalculator.minimumAgeYears);
    });

    test('is at least as strict as the 365-day rule in firestore.rules', () {
      final now = DateTime(2026, 9, 16);
      final ruleCutoff =
          now.subtract(Duration(days: AgeCalculator.minimumAgeYears * 365));
      expect(AgeCalculator.latestAllowedDob(now).isBefore(ruleCutoff), isTrue);
    });
  });
}
