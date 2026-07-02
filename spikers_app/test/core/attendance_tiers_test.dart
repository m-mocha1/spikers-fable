import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/core/utils/attendance_tiers.dart';

void main() {
  group('AttendanceTiers.tierIndex', () {
    test('boundaries map to the documented tiers', () {
      expect(AttendanceTiers.tierIndex(0), 0);
      expect(AttendanceTiers.tierIndex(4), 0);
      expect(AttendanceTiers.tierIndex(5), 1);
      expect(AttendanceTiers.tierIndex(19), 1);
      expect(AttendanceTiers.tierIndex(20), 2);
      expect(AttendanceTiers.tierIndex(49), 2);
      expect(AttendanceTiers.tierIndex(50), 3);
      expect(AttendanceTiers.tierIndex(500), 3);
    });
  });

  group('AttendanceTiers.crossedTier', () {
    test('crossing a boundary returns the new tier', () {
      expect(AttendanceTiers.crossedTier(4, 5), 1);
      expect(AttendanceTiers.crossedTier(19, 20), 2);
      expect(AttendanceTiers.crossedTier(49, 50), 3);
    });

    test('jumping several boundaries returns the highest new tier', () {
      expect(AttendanceTiers.crossedTier(3, 25), 2);
      expect(AttendanceTiers.crossedTier(0, 100), 3);
    });

    test('no boundary crossed → null', () {
      expect(AttendanceTiers.crossedTier(5, 6), isNull);
      expect(AttendanceTiers.crossedTier(0, 4), isNull);
      expect(AttendanceTiers.crossedTier(20, 49), isNull);
    });

    test('same or decreasing count → null (unmarked attendance)', () {
      expect(AttendanceTiers.crossedTier(5, 5), isNull);
      expect(AttendanceTiers.crossedTier(20, 4), isNull);
    });
  });
}
