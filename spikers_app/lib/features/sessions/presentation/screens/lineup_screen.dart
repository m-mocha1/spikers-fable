import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_decorations.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/lineup.dart';
import '../../domain/repositories/sessions_repository.dart';
import '../providers/lineup_providers.dart';
import '../providers/sessions_providers.dart';
import '../widgets/lineup/lineup_player_token.dart';
import '../widgets/lineup/lineup_slot.dart';
import '../widgets/lineup/volleyball_court_painter.dart';

/// Line-up builder for a session: two teams of six on a full court plus one
/// sideline sub slot per extra attendee. Coaches/admins drag players around or
/// shuffle; everyone else gets a read-only view.
class LineupScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const LineupScreen({super.key, required this.sessionId});

  @override
  ConsumerState<LineupScreen> createState() => _LineupScreenState();
}

class _LineupScreenState extends ConsumerState<LineupScreen> {
  /// Smallest court board (court + subs column) that still lays out cleanly.
  static const _minBoardHeight = 440.0;

  /// Rough height of the pool strip + action bar below the board (editors).
  static const _editorChromeHeight = 200.0;

  /// Player picked for tap-to-swap; the next tapped spot receives them.
  String? _selected;

  LineupNotifier get _notifier =>
      ref.read(lineupProvider(widget.sessionId).notifier);

  /// Runs a line-up edit; the notifier shows it instantly and Firestore
  /// reverts a rejected save, so all that's left here is telling the user.
  Future<void> _save(Future<void> edit) async {
    final failed = AppLocalizations.of(context)!.unknownError;
    setState(() => _selected = null);
    try {
      await edit;
    } catch (_) {
      showAppSnackbar(failed);
    }
  }

  void _move(String uid, LineupSlot to, List<String> attendeeIds) {
    HapticFeedback.selectionClick();
    _save(_notifier.move(uid, to, attendeeIds));
  }

  /// Tap on a court/bench spot holding [occupant] (null when empty).
  void _tapSlot(LineupSlot slot, String? occupant, List<String> attendeeIds) {
    final selected = _selected;
    if (selected == null) {
      if (occupant != null) setState(() => _selected = occupant);
    } else if (selected == occupant) {
      setState(() => _selected = null);
    } else {
      _move(selected, slot, attendeeIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final sessionAsync = ref.watch(sessionProvider(widget.sessionId));
    final canEdit = ref.watch(currentUserProvider).value?.isCoach ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.lineup),
            const SizedBox(height: 2),
            Text(
              canEdit ? l.lineupHowTo : l.lineupViewOnly,
              style: const TextStyle(
                color: AppColors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: GradientBackground(
        child: sessionAsync.when(
          loading: () => const LoadingView(),
          error: (_, _) => const ErrorView(),
          data: (session) {
            if (session == null) return const ErrorView();
            final attendeeIds = session.attendeeIds;
            if (attendeeIds.isEmpty) {
              return EmptyStateView(
                icon: Icons.sports_volleyball_outlined,
                title: l.lineupEmpty,
              );
            }
            final profiles =
                ref.watch(lineupProfilesProvider(attendeeIds.join(','))).value ??
                    const <String, PublicProfile>{};
            final lineupAsync = ref.watch(lineupProvider(widget.sessionId));
            if (!lineupAsync.hasValue) {
              return lineupAsync.hasError
                  ? ErrorView(
                      onRetry: () =>
                          ref.invalidate(lineupProvider(widget.sessionId)),
                    )
                  : const LoadingView();
            }
            // Display a line-up that already excludes anyone who left; the
            // stored one is reconciled on the next edit.
            final lineup = lineupAsync.requireValue.reconcile(attendeeIds);
            return _buildBody(l, lineup, attendeeIds, profiles, canEdit);
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations l,
    Lineup lineup,
    List<String> attendeeIds,
    Map<String, PublicProfile> profiles,
    bool canEdit,
  ) {
    final board = DecoratedBox(
      // Same panel as the session screen's cards.
      decoration: AppDecorations.panel(),
      // Court geometry is physical, so it must not mirror in RTL.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: _CourtBoard(
          lineup: lineup,
          profiles: profiles,
          canEdit: canEdit,
          selected: _selected,
          subsLabel: l.lineupSubs,
          teamALabel: l.lineupTeamA,
          teamBLabel: l.lineupTeamB,
          onDrop: (uid, slot) => _move(uid, slot, attendeeIds),
          onTapSlot: (slot, occupant) =>
              _tapSlot(slot, occupant, attendeeIds),
        ),
      ),
    );
    final editor = [
      if (canEdit) ...[
        const SizedBox(height: 12),
        _PoolStrip(
          title: l.lineupAvailable,
          emptyText: l.lineupAllPlaced,
          pool: lineup.pool(attendeeIds),
          profiles: profiles,
          selected: _selected,
          onDrop: (uid) => _move(uid, const LineupSlot.pool(), attendeeIds),
          onTapPlayer: (uid) => setState(
            () => _selected = _selected == uid ? null : uid,
          ),
        ),
        const SizedBox(height: 12),
        _ActionBar(
          clearLabel: l.lineupClear,
          shuffleLabel: l.lineupShuffle,
          onClear: lineup.isEmpty
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  _save(_notifier.clear(attendeeIds));
                },
          onShuffle: () {
            HapticFeedback.mediumImpact();
            _save(_notifier.shuffle(attendeeIds));
          },
        ),
      ],
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Normally the court fills whatever the editor strips leave. When
            // that would squeeze it below a usable size (landscape, split
            // screen, short phones) it keeps a minimum height and the page
            // scrolls instead.
            final needed =
                _minBoardHeight + (canEdit ? _editorChromeHeight : 0);
            if (constraints.maxHeight >= needed) {
              return Column(
                children: [Expanded(child: board), ...editor],
              );
            }
            return SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: _minBoardHeight, child: board),
                  ...editor,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Court position (1-6) shown at each spot, as [Lineup] indices, left to
/// right on screen. Team B faces the net from below, so its front row reads
/// 4-3-2; Team A faces it from above (rotated 180°), so its front row reads
/// 2-3-4 and its back row 1-6-5.
const _teamBFront = [3, 2, 1];
const _teamBBack = [4, 5, 0];
const _teamAFront = [1, 2, 3];
const _teamABack = [0, 5, 4];

/// The full court with the subs column beside it, every spot laid over the
/// painted floor at its real position. Sizes itself to the space it's given.
class _CourtBoard extends StatelessWidget {
  final Lineup lineup;
  final Map<String, PublicProfile> profiles;
  final bool canEdit;
  final String? selected;
  final String subsLabel;
  final String teamALabel;
  final String teamBLabel;
  final void Function(String uid, LineupSlot slot) onDrop;
  final void Function(LineupSlot slot, String? occupant) onTapSlot;

  const _CourtBoard({
    required this.lineup,
    required this.profiles,
    required this.canEdit,
    required this.selected,
    required this.subsLabel,
    required this.teamALabel,
    required this.teamBLabel,
    required this.onDrop,
    required this.onTapSlot,
  });

  static const _pad = 12.0;
  static const _netOverhang = 14.0;
  static const _labelBand = 26.0;
  static const _gap = 10.0;
  static const _subsHeader = 30.0;

  /// Smallest bench slot (disc + name tag) before the subs column scrolls.
  static const _minBenchSlot = 64.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final benchCount = lineup.bench.length;
        // No subs (12 or fewer players): the court takes the full width.
        final subsWidth = benchCount == 0 ? 0.0 : (w * 0.2).clamp(64.0, 92.0);
        final courtColumn =
            w - _pad * 2 - subsWidth - (benchCount == 0 ? 0 : _gap);
        final courtW = min(
          courtColumn - _netOverhang * 2,
          (h - _pad * 2 - _labelBand * 2) / 2,
        );
        final courtH = courtW * 2;
        final courtRect = Rect.fromLTWH(
          _pad + (courtColumn - courtW) / 2,
          (h - courtH) / 2,
          courtW,
          courtH,
        );
        final sidelineRect = benchCount == 0
            ? Rect.zero
            : Rect.fromLTWH(w - _pad - subsWidth, _pad, subsWidth, h - _pad * 2);
        final radius = (courtW / 12.5).clamp(14.0, 24.0);

        final spots = <Widget>[];
        final netY = courtRect.center.dy;
        final half = courtW; // each half is a 9 m square

        void addRow(LineupArea area, List<int> indices, double cy) {
          for (var col = 0; col < indices.length; col++) {
            final cx = courtRect.left + courtW * (col * 2 + 1) / 6;
            spots.add(_spot(
              slot: LineupSlot(area, indices[col]),
              number: '${indices[col] + 1}',
              palette: area == LineupArea.teamA
                  ? LineupPalette.teamA
                  : LineupPalette.teamB,
              radius: radius,
              center: Offset(cx, cy),
            ));
          }
        }

        // Rows mirror across the net; Team A's tags sit above its discs.
        // Front rows hug the net so disc + tag fit inside the 3 m zone.
        final front = 9 + radius + 2.5;
        addRow(LineupArea.teamA, _teamABack, netY - half * 0.64);
        addRow(LineupArea.teamA, _teamAFront, netY - front);
        addRow(LineupArea.teamB, _teamBFront, netY + front);
        addRow(LineupArea.teamB, _teamBBack, netY + half * 0.64);

        // Bench: one slot per sub. Slots share the sideline height but never
        // shrink below a readable size — past that the column scrolls.
        final benchTop = sidelineRect.top + _subsHeader;
        final benchH = sidelineRect.bottom - benchTop;
        final benchSlotH =
            benchCount == 0 ? 0.0 : max(benchH / benchCount, _minBenchSlot);
        final benchRadius = min(
          radius * 0.9,
          (benchSlotH - LineupNameTag.height - 12) / 2,
        ).clamp(12.0, 24.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: VolleyballCourtPainter(
                  courtRect: courtRect,
                  sidelineRect: sidelineRect,
                  // The host panel supplies the background.
                  paintFreeZone: false,
                ),
              ),
            ),
            _teamPill(
              teamALabel,
              AppColors.teamA,
              courtRect,
              top: courtRect.top - _labelBand + 2,
            ),
            _teamPill(
              teamBLabel,
              AppColors.teamB,
              courtRect,
              top: courtRect.bottom + 4,
            ),
            ...spots,
            if (benchCount > 0) ...[
              Positioned(
                left: sidelineRect.left,
                width: sidelineRect.width,
                top: sidelineRect.top + 9,
                child: Text(
                  subsLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Positioned(
                left: sidelineRect.left,
                width: sidelineRect.width,
                top: benchTop,
                height: benchH,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < benchCount; i++)
                        SizedBox(
                          height: benchSlotH,
                          child: Center(
                            child: _slotView(
                              slot: LineupSlot(LineupArea.bench, i),
                              number: '${Lineup.teamSize + i + 1}',
                              palette: LineupPalette.sub,
                              radius: benchRadius,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _teamPill(String label, Color color, Rect court,
      {required double top}) {
    return Positioned(
      left: court.left,
      width: court.width,
      top: top,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _spot({
    required LineupSlot slot,
    required String number,
    required LineupPalette palette,
    required double radius,
    required Offset center,
  }) {
    final tokenWidth = LineupPlayerToken.widthFor(radius);
    final tagAbove = slot.area == LineupArea.teamA;
    return Positioned(
      left: center.dx - tokenWidth / 2,
      top: center.dy -
          radius -
          2.5 -
          (tagAbove ? 4 + LineupNameTag.height : 0),
      child: _slotView(
        slot: slot,
        number: number,
        palette: palette,
        radius: radius,
      ),
    );
  }

  Widget _slotView({
    required LineupSlot slot,
    required String number,
    required LineupPalette palette,
    required double radius,
  }) {
    final uid = lineup.at(slot);
    return LineupSlotView(
      uid: uid,
      profile: uid == null ? null : profiles[uid],
      number: number,
      palette: palette,
      radius: radius,
      canEdit: canEdit,
      selected: uid != null && uid == selected,
      tagAbove: slot.area == LineupArea.teamA,
      onDrop: (dropped) => onDrop(dropped, slot),
      onTap: () => onTapSlot(slot, uid),
    );
  }
}

/// Attendees not yet placed, in one horizontal row. Also a drop target:
/// dragging a player here takes them off the court/bench.
class _PoolStrip extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<String> pool;
  final Map<String, PublicProfile> profiles;
  final String? selected;
  final ValueChanged<String> onDrop;
  final ValueChanged<String> onTapPlayer;

  const _PoolStrip({
    required this.title,
    required this.emptyText,
    required this.pool,
    required this.profiles,
    required this.selected,
    required this.onDrop,
    required this.onTapPlayer,
  });

  static const _radius = 20.0;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => !pool.contains(d.data),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppColors.navyLight.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hovering
                  ? AppColors.gold
                  : AppColors.white.withValues(alpha: 0.08),
              width: hovering ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title (${pool.length})',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: _radius * 2 + 9 + LineupNameTag.height,
                child: pool.isEmpty
                    ? Center(
                        child: Text(
                          emptyText,
                          style: const TextStyle(color: AppColors.grey),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: pool.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 2),
                        itemBuilder: (_, i) {
                          final uid = pool[i];
                          return LineupPlayerToken(
                            key: ValueKey(uid),
                            uid: uid,
                            name: profiles[uid]?.name ?? '',
                            photoUrl: profiles[uid]?.photoUrl,
                            radius: _radius,
                            selected: uid == selected,
                            canEdit: true,
                            onTap: () => onTapPlayer(uid),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionBar extends StatelessWidget {
  final String clearLabel;
  final String shuffleLabel;
  final VoidCallback? onClear;
  final VoidCallback onShuffle;

  const _ActionBar({
    required this.clearLabel,
    required this.shuffleLabel,
    required this.onClear,
    required this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.restart_alt, size: 20),
            label: Text(clearLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.white,
              minimumSize: const Size.fromHeight(50),
              side: BorderSide(
                color: AppColors.white.withValues(alpha: 0.35),
              ),
              shape: shape,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: onShuffle,
            icon: const Icon(Icons.shuffle, size: 20),
            label: Text(shuffleLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navyBlue,
              minimumSize: const Size.fromHeight(50),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              shape: shape,
            ),
          ),
        ),
      ],
    );
  }
}
