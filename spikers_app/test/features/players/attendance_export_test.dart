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
  lastPaid: 'Last Payment Date',
  membershipStatus: 'Membership Status',
  membershipExpiry: 'Membership Expiry',
  male: 'Male',
  female: 'Female',
  statusActive: 'Active',
  statusExpired: 'Inactive',
  statusLifetime: 'Lifetime',
);

PlayerSummary _player(
  String name, {
  String? gender = 'male',
  int attended = 0,
  DateTime? dob,
  DateTime? createdAt,
  DateTime? paidUntil,
  bool lifetimeMember = false,
}) {
  return PlayerSummary(
    uid: name,
    name: name,
    gender: gender,
    photoUrl: '',
    dateOfBirth: dob,
    createdAt: createdAt,
    attendanceCount: attended,
    paidUntil: paidUntil,
    lifetimeMember: lifetimeMember,
    injured: false,
  );
}

/// Plain-text view of a decoded row (TextCellValue round-trips as spans).
List<String> _rowText(List<Data?> row) =>
    row.map((c) => c?.value?.toString() ?? '').toList();

List<List<String>> _rows(List<int> bytes) =>
    Excel.decodeBytes(bytes)[_sheet].rows.map(_rowText).toList();

void main() {
  test('defaults to every column, one row per player, sorted by name', () {
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
      lastPaid: {'Adam': DateTime(2026, 6, 1)},
      labels: _labels,
    );

    final excel = Excel.decodeBytes(bytes);
    expect(excel.sheets.keys, [_sheet]);
    final rows = excel[_sheet].rows;
    expect(rows, hasLength(4));

    expect(_rowText(rows[0]), [
      'Full Name',
      'Gender',
      'Age',
      'Registration Date',
      'Sessions Attended',
      'Last Session Attended',
      'Last Payment Date',
      'Membership Status',
      'Membership Expiry',
    ]);
    final age = '${AgeCalculator.fromDate(dob)}';
    // Sorted case-insensitively: Adam, Maya, zainab. Dates are date-only
    // (yyyy-MM-dd); zainab never attended and nobody but Adam has paid.
    expect(_rowText(rows[1]), [
      'Adam', 'Male', age, '2025-03-09', '3', //
      '2026-06-28', '2026-06-01', 'Inactive', '',
    ]);
    expect(_rowText(rows[2]), [
      'Maya', 'Female', age, '2025-03-09', '7', //
      '2026-07-01', '', 'Inactive', '',
    ]);
    expect(_rowText(rows[3]), [
      'zainab', 'Female', age, '2025-03-09', '12', //
      '', '', 'Inactive', '',
    ]);
  });

  test('writes only the selected columns, in canonical order', () {
    final bytes = buildAttendanceXlsx(
      players: [_player('Adam', attended: 5)],
      // Deliberately out of declaration order: the workbook must not follow
      // the set's order.
      columns: {ExportColumn.lastPaid, ExportColumn.gender},
      lastPaid: {'Adam': DateTime(2026, 5, 4)},
      labels: _labels,
    );

    final rows = _rows(bytes);
    expect(rows[0], ['Full Name', 'Gender', 'Last Payment Date']);
    expect(rows[1], ['Adam', 'Male', '2026-05-04']);
  });

  test('writes a name-only workbook when no columns are selected', () {
    final bytes = buildAttendanceXlsx(
      players: [_player('Maya', gender: 'female'), _player('Adam')],
      columns: const {},
      labels: _labels,
    );

    expect(_rows(bytes), [
      ['Full Name'],
      ['Adam'],
      ['Maya'],
    ]);
  });

  test('reports the three membership states', () {
    final future = DateTime.now().add(const Duration(days: 10));
    final past = DateTime.now().subtract(const Duration(days: 10));
    final bytes = buildAttendanceXlsx(
      players: [
        _player('Active', paidUntil: future),
        _player('Expired', paidUntil: past),
        _player('Forever', lifetimeMember: true, paidUntil: past),
      ],
      columns: const {
        ExportColumn.membershipStatus,
        ExportColumn.membershipExpiry,
      },
      labels: _labels,
    );

    final rows = _rows(bytes);
    expect(rows[0], ['Full Name', 'Membership Status', 'Membership Expiry']);
    expect(rows[1], ['Active', 'Active', _ymd(future)]);
    expect(rows[2], ['Expired', 'Inactive', _ymd(past)]);
    // A lifetime member outranks a stale paidUntil and has no expiry to report.
    expect(rows[3], ['Forever', 'Lifetime', '']);
  });

  test('leaves the gender cell empty when the player never set one', () {
    final bytes = buildAttendanceXlsx(
      players: [_player('Adam', gender: null)],
      columns: const {ExportColumn.gender},
      labels: _labels,
    );

    expect(_rows(bytes)[1], ['Adam', '']);
  });

  test('leaves age and registration cells empty when data is missing', () {
    final bytes = buildAttendanceXlsx(
      players: [_player('Adam', attended: 5)],
      columns: const {
        ExportColumn.gender,
        ExportColumn.age,
        ExportColumn.registered,
        ExportColumn.sessionsAttended,
        ExportColumn.lastSession,
      },
      labels: _labels,
    );

    expect(_rows(bytes)[1], ['Adam', 'Male', '', '', '5', '']);
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

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
