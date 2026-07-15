import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/app_choice_chips.dart';
import '../../../../core/widgets/branded_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../payments/presentation/providers/payments_providers.dart';
import '../../../sessions/presentation/providers/sessions_providers.dart';
import '../../application/attendance_export.dart';
import '../../domain/entities/player_summary.dart';
import '../providers/export_options_provider.dart';
import '../providers/players_providers.dart';

/// Coach-only export configuration: pick which players (by gender) and which
/// columns go into the attendance workbook, then share it. Reached from the
/// download action in the Players tab AppBar.
class ExportOptionsScreen extends ConsumerStatefulWidget {
  const ExportOptionsScreen({super.key});

  @override
  ConsumerState<ExportOptionsScreen> createState() =>
      _ExportOptionsScreenState();
}

class _ExportOptionsScreenState extends ConsumerState<ExportOptionsScreen> {
  bool _exporting = false;

  /// The roster narrowed to the chosen gender. A player who never set a gender
  /// has none to match, so they only appear under 'all'.
  List<PlayerSummary> _filtered(List<PlayerSummary> players, String gender) =>
      players.where((p) => gender == 'all' || p.gender == gender).toList();

  Future<void> _export(List<PlayerSummary> players) async {
    final l = AppLocalizations.of(context)!;
    final options = ref.read(exportOptionsProvider);
    final selected = _filtered(players, options.gender);
    if (selected.isEmpty) return;

    // iPad/macOS share sheets are popovers and need an anchor rect; captured
    // before the async gap along with everything else context-derived.
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    setState(() => _exporting = true);
    try {
      // One bounded query per player per column, so each fan-out only runs
      // when its column was actually ticked; the two run concurrently.
      final sessionsRepo = ref.read(sessionsRepositoryProvider);
      final paymentsRepo = ref.read(paymentsRepositoryProvider);
      final wantsLastSession =
          options.columns.contains(ExportColumn.lastSession);
      final wantsLastPaid = options.columns.contains(ExportColumn.lastPaid);

      final fanOuts = await Future.wait([
        wantsLastSession
            ? Future.wait(
                selected.map((p) => sessionsRepo.fetchLastAttendedTime(p.uid)))
            : Future.value(<DateTime?>[]),
        wantsLastPaid
            ? Future.wait(
                selected.map((p) => paymentsRepo.fetchLastPaidAt(p.uid)))
            : Future.value(<DateTime?>[]),
      ]);

      final bytes = buildAttendanceXlsx(
        players: selected,
        columns: options.columns,
        lastAttended: _byUid(selected, fanOuts[0]),
        lastPaid: _byUid(selected, fanOuts[1]),
        rtl: rtl,
        labels: AttendanceExportLabels(
          name: l.name,
          gender: l.gender,
          age: l.age,
          registered: l.registrationDate,
          sessionsAttended: l.sessionsAttendedTitle,
          lastAttended: l.lastSessionDate,
          lastPaid: l.lastPaidDate,
          membershipStatus: l.membershipStatus,
          membershipExpiry: l.membershipExpiry,
          male: l.male,
          female: l.female,
          statusActive: l.paid,
          statusExpired: l.unpaid,
          statusLifetime: l.membershipLifetime,
        ),
      );
      final stamp = DateFormat('yyyy-MM-dd', 'en').format(DateTime.now());
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/spikers_attendance_$stamp.xlsx');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      showAppSnackbar(l.unknownError);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Zips a fan-out result back onto the players it was fetched for, dropping
  /// the nulls (never attended / never paid). An empty [times] list means the
  /// column wasn't selected, so nothing was fetched.
  Map<String, DateTime> _byUid(
      List<PlayerSummary> players, List<DateTime?> times) {
    return {
      for (var i = 0; i < times.length; i++)
        if (times[i] != null) players[i].uid: times[i]!,
    };
  }

  String _columnLabel(ExportColumn column, AppLocalizations l) {
    switch (column) {
      case ExportColumn.gender:
        return l.gender;
      case ExportColumn.age:
        return l.age;
      case ExportColumn.registered:
        return l.registrationDate;
      case ExportColumn.sessionsAttended:
        return l.sessionsAttendedTitle;
      case ExportColumn.lastSession:
        return l.lastSessionDate;
      case ExportColumn.lastPaid:
        return l.lastPaidDate;
      case ExportColumn.membershipStatus:
        return l.membershipStatus;
      case ExportColumn.membershipExpiry:
        return l.membershipExpiry;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final options = ref.watch(exportOptionsProvider);
    final players = ref.watch(playersProvider).value ?? const <PlayerSummary>[];
    final matching = _filtered(players, options.gender);

    return Scaffold(
      appBar: AppBar(title: Text(l.exportAttendance)),
      // SafeArea keeps the bottom CTA above the Android gesture bar.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl),
          child: AppFadeIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.gender.toUpperCase(), style: AppTextStyles.eyebrow),
                const SizedBox(height: AppSpacing.sm),
                AppChoiceChips<String>(
                  value: options.gender,
                  expanded: true,
                  onSelected: (v) =>
                      ref.read(exportOptionsProvider.notifier).setGender(v),
                  options: [
                    AppChoiceChipOption(value: 'all', label: l.allGenders),
                    AppChoiceChipOption(value: 'male', label: l.male),
                    AppChoiceChipOption(value: 'female', label: l.female),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(l.exportColumns.toUpperCase(),
                    style: AppTextStyles.eyebrow),
                const SizedBox(height: AppSpacing.sm),
                _ColumnsCard(
                  columns: options.columns,
                  labelFor: (c) => _columnLabel(c, l),
                  onToggle: (c, v) => ref
                      .read(exportOptionsProvider.notifier)
                      .toggleColumn(c, v),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l.playersWillBeExported(matching.length),
                  style: const TextStyle(
                      color: AppColors.grey, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.md),
                BrandedButton(
                  label: l.export,
                  isLoading: _exporting,
                  onPressed:
                      matching.isEmpty ? null : () => _export(players),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The column checkboxes, grouped in the app's bordered section container.
/// Name is deliberately absent — it is always the first column.
class _ColumnsCard extends StatelessWidget {
  final Set<ExportColumn> columns;
  final String Function(ExportColumn) labelFor;
  final void Function(ExportColumn, bool) onToggle;

  const _ColumnsCard({
    required this.columns,
    required this.labelFor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.navyElevated),
      ),
      child: Column(
        children: [
          for (final column in ExportColumn.values)
            CheckboxListTile(
              value: columns.contains(column),
              onChanged: (v) => onToggle(column, v ?? false),
              title: Text(labelFor(column),
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              activeColor: AppColors.gold,
              checkColor: AppColors.navyBlue,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}
