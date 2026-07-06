import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spikers_app/core/utils/age_calculator.dart';
import 'package:spikers_app/features/players/application/attendance_export.dart';
import 'package:spikers_app/features/players/domain/entities/player_summary.dart';

// The builder keeps the workbook's default sheet ('Sheet1'): renaming it
// breaks RTL persistence in excel 4.0.6.
const _sheet = 'Sheet1';

const _labels = AttendanceExportLabels(
  name: 'Full Name',
  gender: 'Gender',
  age: 'Age',
  registered: 'Registration Date',
  sessionsAttended: 'Sessions Attended',
  lastAttended: 'Last Session Attended',
  male: 'Male',
  female: 'Female',
);

PlayerSummary _player(
  String name, {
  String gender = 'male',
  int attended = 0,
  DateTime? dob,
  DateTime? createdAt,
}) {
  return PlayerSummary(
    uid: name,
    name: name,
    gender: gender,
    photoUrl: '',
    dateOfBirth: dob,
    createdAt: createdAt,
    attendanceCount: attended,
    paidUntil: null,
    lifetimeMember: false,
    injured: false,
  );
}

/// Plain-text view of a decoded row (TextCellValue round-trips as spans).
List<String> _rowText(List<Data?> row) =>
    row.map((c) => c?.value?.toString() ?? '').toList();

void main() {
  test('writes header row and one row per player, sorted by name', () {
    final dob = DateTime(2000, 1, 1);
    final registered = DateTime(2025, 3, 9, 14, 30);
    final bytes = buildAttendanceXlsx(
      players: [
        _player('zainab',
            gender: 'female', attended: 12, dob: dob, createdAt: registered),
        _player('Adam', attended: 3, dob: dob, createdAt: registered),
        _player('Maya',
            gender: 'female', attended: 7, dob: dob, createdAt: registered),
      ],
      lastAttended: {
        'Adam': DateTime(2026, 6, 28, 18),
        'Maya': DateTime(2026, 7, 1, 20),
      },
      labels: _labels,
    );

    final excel = Excel.decodeBytes(bytes);
    expect(excel.sheets.keys, [_sheet]);
    final rows = excel[_sheet].rows;
    expect(rows, hasLength(4));

    expect(
      _rowText(rows[0]),
      [
        'Full Name',
        'Gender',
        'Age',
        'Registration Date',
        'Sessions Attended',
        'Last Session Attended',
      ],
    );
    final age = '${AgeCalculator.fromDate(dob)}';
    // Sorted case-insensitively: Adam, Maya, zainab. Dates are date-only
    // (yyyy-MM-dd), and zainab has no last-attended entry (never attended).
    expect(
        _rowText(rows[1]), ['Adam', 'Male', age, '2025-03-09', '3', '2026-06-28']);
    expect(
        _rowText(rows[2]), ['Maya', 'Female', age, '2025-03-09', '7', '2026-07-01']);
    expect(
        _rowText(rows[3]), ['zainab', 'Female', age, '2025-03-09', '12', '']);
  });

  test('leaves age and registration cells empty when data is missing', () {
    final bytes = buildAttendanceXlsx(
      players: [_player('Adam', attended: 5)],
      labels: _labels,
    );

    final rows = Excel.decodeBytes(bytes)[_sheet].rows;
    expect(_rowText(rows[1]), ['Adam', 'Male', '', '', '5', '']);
  });

  test('marks the sheet right-to-left when requested', () {
    final bytes = buildAttendanceXlsx(
      players: [_player('Adam')],
      labels: _labels,
      rtl: true,
    );

    expect(Excel.decodeBytes(bytes)[_sheet].isRTL, isTrue);
  });
}
