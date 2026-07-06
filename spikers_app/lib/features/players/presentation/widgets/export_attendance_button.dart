import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sessions/presentation/providers/sessions_providers.dart';
import '../../application/attendance_export.dart';
import '../providers/players_providers.dart';

/// AppBar action (coach roster only) that exports every player's attendance
/// summary as an .xlsx file and opens the system share sheet.
class ExportAttendanceButton extends ConsumerStatefulWidget {
  const ExportAttendanceButton({super.key});

  @override
  ConsumerState<ExportAttendanceButton> createState() =>
      _ExportAttendanceButtonState();
}

class _ExportAttendanceButtonState
    extends ConsumerState<ExportAttendanceButton> {
  bool _exporting = false;

  Future<void> _export() async {
    final l = AppLocalizations.of(context)!;
    final players = ref.read(playersProvider).value;
    if (players == null || players.isEmpty) return;

    // iPad/macOS share sheets are popovers and need an anchor rect; captured
    // before the async gap along with everything else context-derived.
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    setState(() => _exporting = true);
    try {
      // One bounded query per player; the roster is small (see watchPlayers).
      final sessionsRepo = ref.read(sessionsRepositoryProvider);
      final lastTimes = await Future.wait(
          players.map((p) => sessionsRepo.fetchLastAttendedTime(p.uid)));
      final lastAttended = <String, DateTime>{
        for (var i = 0; i < players.length; i++)
          if (lastTimes[i] != null) players[i].uid: lastTimes[i]!,
      };
      final bytes = buildAttendanceXlsx(
        players: players,
        lastAttended: lastAttended,
        rtl: rtl,
        labels: AttendanceExportLabels(
          name: l.name,
          gender: l.gender,
          age: l.age,
          registered: l.registrationDate,
          sessionsAttended: l.sessionsAttendedTitle,
          lastAttended: l.lastSessionDate,
          male: l.male,
          female: l.female,
        ),
      );
      final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final hasPlayers = ref.watch(playersProvider).value?.isNotEmpty ?? false;
    if (_exporting) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      tooltip: l.exportAttendance,
      icon: const Icon(Icons.file_download_outlined),
      onPressed: hasPlayers ? _export : null,
    );
  }
}
