import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/entities/session_model.dart';
import '../../../domain/lineup.dart';
import '../../../domain/repositories/sessions_repository.dart';
import '../../providers/lineup_providers.dart';
import 'lineup_player_token.dart';
import 'lineup_slot.dart';
import 'volleyball_court_painter.dart';

/// Session-detail panel previewing the line-up: the court turned sideways
/// (net down the middle, Team A left, Team B right) with both starting sixes
/// in their real positions. Subs are left to the full screen. Same footprint
/// as the countdown hero above it; transparent, so the host wraps it in its
/// panel decoration. Tapping opens [Routes.sessionLineup].
class LineupPreviewCard extends ConsumerWidget {
  /// Matches the countdown hero so the two panels read as a pair.
  static const double height = 190;

  final SessionModel session;
  const LineupPreviewCard({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final attendeeIds = session.attendeeIds;
    // Until the stream lands, show the empty court rather than a spinner —
    // the frame never jumps.
    final lineup =
        (ref.watch(lineupProvider(session.id)).value ?? Lineup.empty())
            .reconcile(attendeeIds);
    // Same family key as the line-up screen, so opening it reuses the fetch.
    final profiles =
        ref.watch(lineupProfilesProvider(attendeeIds.join(','))).value ??
            const <String, PublicProfile>{};

    return Semantics(
      button: true,
      label: l.lineup,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(Routes.sessionLineup, extra: session.id),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Court geometry is physical, so it must not mirror in RTL.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: IgnorePointer(
                    child: _SidewaysCourt(lineup: lineup, profiles: profiles),
                  ),
                ),
                // Top-right corner sits outside every spot (Team B's back
                // column stops short of the end line), so it can't cover a
                // player. Physical side on purpose: the court never mirrors.
                const Positioned(top: 6, right: 6, child: _OpenBadge()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Court position (as [Lineup] indices) at each spot, top to bottom. Team A
/// faces the net from the left, so its left hand is the top of the screen:
/// front column reads 4-3-2, back column 5-6-1. Team B faces it from the
/// right, so both columns read the other way round.
const _teamAFront = [3, 2, 1];
const _teamABack = [4, 5, 0];
const _teamBFront = [1, 2, 3];
const _teamBBack = [0, 5, 4];

class _SidewaysCourt extends StatelessWidget {
  final Lineup lineup;
  final Map<String, PublicProfile> profiles;
  const _SidewaysCourt({required this.lineup, required this.profiles});

  /// Vertical room above/below the court for the net posts.
  static const _padV = 13.0;

  /// Net reach past the sidelines; posts sit inside [_padV] at this value.
  static const _netOverhang = 7.0;
  static const _padH = 10.0;

  /// Minimum gap between rows, and between the outer rows and the sidelines.
  static const _minGap = 5.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      // The court fills the card's height; its length runs across, capped at
      // the real 2:1 ratio. On narrow phones it's a little shorter than
      // 18 m × 9 m so three rows of players still fit with clearance.
      final courtH = h - _padV * 2;
      final courtW = min(courtH * 2, w - _padH * 2);
      final court = Rect.fromLTWH(
        (w - courtW) / 2,
        (h - courtH) / 2,
        courtW,
        courtH,
      );
      final netX = court.center.dx;
      final half = courtW / 2;

      // Three spots (disc + slim tag) per column with at least [_minGap]
      // around each; the disc takes whatever height is left.
      const tagH = LineupNameTag.denseHeight;
      // Stack = white ring (2r + 5) + 4 gap + tag.
      final radius =
          (((courtH - _minGap * 4) / 3 - 9 - tagH) / 2).clamp(8.0, 15.0);
      final stackH = radius * 2 + 9 + tagH;
      final gap = (courtH - stackH * 3) / 4;
      final tokenW = LineupPlayerToken.widthFor(radius);
      // Front column clear of the net, back column clear of the end line.
      final frontOffset = max(half * 0.25, tokenW / 2 + 9);
      final backOffset = min(half * 0.72, half - tokenW / 2 - 9);

      final spots = <Widget>[];
      void addColumn(LineupArea area, List<int> indices, double cx) {
        for (var row = 0; row < indices.length; row++) {
          final top = court.top + gap + (stackH + gap) * row;
          final slot = LineupSlot(area, indices[row]);
          final uid = lineup.at(slot);
          spots.add(Positioned(
            left: cx - tokenW / 2,
            top: top,
            child: LineupSlotView(
              uid: uid,
              profile: uid == null ? null : profiles[uid],
              number: '${indices[row] + 1}',
              palette: area == LineupArea.teamA
                  ? LineupPalette.teamA
                  : LineupPalette.teamB,
              radius: radius,
              canEdit: false,
              selected: false,
              dense: true,
              onDrop: (_) {},
              onTap: () {},
            ),
          ));
        }
      }

      addColumn(LineupArea.teamA, _teamABack, netX - backOffset);
      addColumn(LineupArea.teamA, _teamAFront, netX - frontOffset);
      addColumn(LineupArea.teamB, _teamBFront, netX + frontOffset);
      addColumn(LineupArea.teamB, _teamBBack, netX + backOffset);

      return Stack(
        children: [
          // The painter draws the court upright (net across the middle);
          // a quarter turn lays it on its side. It's symmetric, so centring
          // it in the turned space centres it on screen too.
          Positioned.fill(
            child: RotatedBox(
              quarterTurns: 1,
              child: CustomPaint(
                painter: VolleyballCourtPainter(
                  courtRect: Rect.fromLTWH(
                    (h - courtH) / 2,
                    (w - courtW) / 2,
                    courtH,
                    courtW,
                  ),
                  sidelineRect: Rect.zero,
                  showAttackLines: false,
                  netOverhang: _netOverhang,
                  // The host panel supplies the background.
                  paintFreeZone: false,
                ),
              ),
            ),
          ),
          ...spots,
        ],
      );
    });
  }
}

/// Small frosted "open" badge in the card's corner — hints the panel is
/// tappable without covering the court.
class _OpenBadge extends StatelessWidget {
  const _OpenBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: const Icon(Icons.open_in_full, size: 12, color: AppColors.gold),
    );
  }
}
