import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/attendance_export.dart';

/// What the coach picked on the export options screen.
class ExportOptions {
  /// 'all', 'male' or 'female' — the same filter vocabulary the players tab
  /// and leaderboard use.
  final String gender;
  final Set<ExportColumn> columns;

  const ExportOptions({required this.gender, required this.columns});

  ExportOptions copyWith({String? gender, Set<ExportColumn>? columns}) =>
      ExportOptions(
        gender: gender ?? this.gender,
        columns: columns ?? this.columns,
      );
}

/// Export options with SharedPreferences persistence, so a coach who always
/// exports the same shape doesn't re-tick the boxes every month. Mirrors
/// [LocaleNotifier] — the app's established prefs-backed notifier pattern.
class ExportOptionsNotifier extends Notifier<ExportOptions> {
  static const _genderKey = 'export_gender';
  static const _columnsKey = 'export_columns';

  @override
  ExportOptions build() {
    _loadSaved();
    return ExportOptions(
      gender: 'all',
      columns: ExportColumn.values.toSet(),
    );
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final gender = prefs.getString(_genderKey);
    final saved = prefs.getStringList(_columnsKey);
    state = ExportOptions(
      gender: gender ?? state.gender,
      // Unknown names are dropped rather than thrown on, so renaming or
      // removing a column can't break launch for someone with saved prefs.
      columns: saved == null
          ? state.columns
          : ExportColumn.values
              .where((c) => saved.contains(c.name))
              .toSet(),
    );
  }

  Future<void> setGender(String gender) async {
    state = state.copyWith(gender: gender);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_genderKey, gender);
  }

  Future<void> toggleColumn(ExportColumn column, bool selected) async {
    final next = {...state.columns};
    selected ? next.add(column) : next.remove(column);
    state = state.copyWith(columns: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _columnsKey, next.map((c) => c.name).toList());
  }
}

final exportOptionsProvider =
    NotifierProvider<ExportOptionsNotifier, ExportOptions>(
        ExportOptionsNotifier.new);
