import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../../core/utils/age_calculator.dart';
import '../domain/entities/player_summary.dart';

/// Localized strings for [buildAttendanceXlsx], passed in explicitly so the
/// builder stays a pure function (testable without a BuildContext).
class AttendanceExportLabels {
  final String name;
  final String gender;
  final String age;
  final String registered;
  final String sessionsAttended;
  final String lastAttended;
  final String male;
  final String female;

  const AttendanceExportLabels({
    required this.name,
    required this.gender,
    required this.age,
    required this.registered,
    required this.sessionsAttended,
    required this.lastAttended,
    required this.male,
    required this.female,
  });
}

/// Builds the coach-facing attendance summary workbook: one bold header row,
/// then one row per player sorted alphabetically by name. [lastAttended] maps
/// player uid to the start time of the last session they attended (absent =
/// never attended). Returns the encoded .xlsx bytes, ready to be written to a
/// file and shared.
Uint8List buildAttendanceXlsx({
  required List<PlayerSummary> players,
  required AttendanceExportLabels labels,
  Map<String, DateTime> lastAttended = const {},
  bool rtl = false,
}) {
  final excel = Excel.createExcel();
  // The sheet keeps the default name on purpose: excel 4.0.6 only persists
  // the RTL flag for the pristine default sheet — rename() drops it on encode.
  final sheet = excel[excel.getDefaultSheet()!];
  sheet.isRTL = rtl;

  sheet.appendRow([
    TextCellValue(labels.name),
    TextCellValue(labels.gender),
    TextCellValue(labels.age),
    TextCellValue(labels.registered),
    TextCellValue(labels.sessionsAttended),
    TextCellValue(labels.lastAttended),
  ]);
  final headerStyle = CellStyle(bold: true);
  for (var col = 0; col < 6; col++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
        .cellStyle = headerStyle;
  }

  final sorted = [...players]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  for (final p in sorted) {
    sheet.appendRow([
      TextCellValue(p.name),
      TextCellValue(p.gender == 'female' ? labels.female : labels.male),
      p.dateOfBirth == null
          ? TextCellValue('')
          : IntCellValue(AgeCalculator.fromDate(p.dateOfBirth!)),
      TextCellValue(_dateOrEmpty(p.createdAt)),
      IntCellValue(p.attendanceCount),
      TextCellValue(_dateOrEmpty(lastAttended[p.uid])),
    ]);
  }

  return Uint8List.fromList(excel.encode()!);
}

/// yyyy-MM-dd, or '' for null — locale-independent so the workbook reads the
/// same (and sorts as text) in both the English and Arabic exports.
String _dateOrEmpty(DateTime? d) {
  if (d == null) return '';
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}
