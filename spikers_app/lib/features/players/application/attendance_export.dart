import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../../core/utils/age_calculator.dart';
import '../domain/entities/player_summary.dart';

/// The optional export columns, declared in the order they appear in the
/// workbook. The coach picks a subset on the export options screen; the name
/// column is always written first and is not selectable.
enum ExportColumn {
  gender,
  age,
  registered,
  sessionsAttended,
  lastSession,
  lastPaid,
  membershipStatus,
  membershipExpiry,
}

/// Localized strings for [buildAttendanceXlsx], passed in explicitly so the
/// builder stays a pure function (testable without a BuildContext).
class AttendanceExportLabels {
  final String name;
  final String gender;
  final String age;
  final String registered;
  final String sessionsAttended;
  final String lastAttended;
  final String lastPaid;
  final String membershipStatus;
  final String membershipExpiry;
  final String male;
  final String female;
  final String statusActive;
  final String statusExpired;
  final String statusLifetime;

  const AttendanceExportLabels({
    required this.name,
    required this.gender,
    required this.age,
    required this.registered,
    required this.sessionsAttended,
    required this.lastAttended,
    required this.lastPaid,
    required this.membershipStatus,
    required this.membershipExpiry,
    required this.male,
    required this.female,
    required this.statusActive,
    required this.statusExpired,
    required this.statusLifetime,
  });
}

/// Builds the coach-facing attendance workbook: one bold header row, then one
/// row per player sorted alphabetically by name. [players] is written as given
/// (the caller applies any gender filter); [columns] selects which optional
/// columns follow the always-present name column, and they are always emitted
/// in [ExportColumn] declaration order regardless of set order.
///
/// [lastAttended] maps player uid to the start time of the last session they
/// attended and [lastPaid] to the date of their most recent payment; an absent
/// uid means never. Returns the encoded .xlsx bytes, ready to be written to a
/// file and shared.
Uint8List buildAttendanceXlsx({
  required List<PlayerSummary> players,
  required AttendanceExportLabels labels,
  Set<ExportColumn> columns = const {
    ExportColumn.gender,
    ExportColumn.age,
    ExportColumn.registered,
    ExportColumn.sessionsAttended,
    ExportColumn.lastSession,
    ExportColumn.lastPaid,
    ExportColumn.membershipStatus,
    ExportColumn.membershipExpiry,
  },
  Map<String, DateTime> lastAttended = const {},
  Map<String, DateTime> lastPaid = const {},
  bool rtl = false,
}) {
  final excel = Excel.createExcel();
  // The sheet keeps the default name on purpose: excel 4.0.6 only persists
  // the RTL flag for the pristine default sheet — rename() drops it on encode.
  final sheet = excel[excel.getDefaultSheet()!];
  sheet.isRTL = rtl;

  // Declaration order, not selection order, so the workbook layout is stable
  // however the coach ticked the boxes.
  final selected =
      ExportColumn.values.where(columns.contains).toList(growable: false);

  sheet.appendRow([
    TextCellValue(labels.name),
    for (final column in selected) TextCellValue(_headerFor(column, labels)),
  ]);
  final headerStyle = CellStyle(bold: true);
  for (var col = 0; col < selected.length + 1; col++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
        .cellStyle = headerStyle;
  }

  final sorted = [...players]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  for (final p in sorted) {
    sheet.appendRow([
      TextCellValue(p.name),
      for (final column in selected)
        _cellFor(column, p, labels, lastAttended, lastPaid),
    ]);
  }

  return Uint8List.fromList(excel.encode()!);
}

String _headerFor(ExportColumn column, AttendanceExportLabels labels) {
  switch (column) {
    case ExportColumn.gender:
      return labels.gender;
    case ExportColumn.age:
      return labels.age;
    case ExportColumn.registered:
      return labels.registered;
    case ExportColumn.sessionsAttended:
      return labels.sessionsAttended;
    case ExportColumn.lastSession:
      return labels.lastAttended;
    case ExportColumn.lastPaid:
      return labels.lastPaid;
    case ExportColumn.membershipStatus:
      return labels.membershipStatus;
    case ExportColumn.membershipExpiry:
      return labels.membershipExpiry;
  }
}

CellValue _cellFor(
  ExportColumn column,
  PlayerSummary p,
  AttendanceExportLabels labels,
  Map<String, DateTime> lastAttended,
  Map<String, DateTime> lastPaid,
) {
  switch (column) {
    case ExportColumn.gender:
      // Gender is optional on the profile, so it stays blank rather than
      // defaulting a genderless player into one of the buckets.
      return TextCellValue(p.gender == null
          ? ''
          : (p.gender == 'female' ? labels.female : labels.male));
    case ExportColumn.age:
      return p.dateOfBirth == null
          ? TextCellValue('')
          : IntCellValue(AgeCalculator.fromDate(p.dateOfBirth!));
    case ExportColumn.registered:
      return TextCellValue(_dateOrEmpty(p.createdAt));
    case ExportColumn.sessionsAttended:
      return IntCellValue(p.attendanceCount);
    case ExportColumn.lastSession:
      return TextCellValue(_dateOrEmpty(lastAttended[p.uid]));
    case ExportColumn.lastPaid:
      return TextCellValue(_dateOrEmpty(lastPaid[p.uid]));
    case ExportColumn.membershipStatus:
      return TextCellValue(p.lifetimeMember
          ? labels.statusLifetime
          : p.isPaid
              ? labels.statusActive
              : labels.statusExpired);
    case ExportColumn.membershipExpiry:
      // Lifetime members have no expiry date to report.
      return TextCellValue(
          p.lifetimeMember ? '' : _dateOrEmpty(p.paidUntil));
  }
}

/// yyyy-MM-dd, or '' for null — locale-independent so the workbook reads the
/// same (and sorts as text) in both the English and Arabic exports.
String _dateOrEmpty(DateTime? d) {
  if (d == null) return '';
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}
