import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';

/// Paints a full volleyball court seen from above (net across the middle)
/// on its free zone, plus the sideline strip where subs sit. [courtRect] and
/// [sidelineRect] are in canvas coordinates and computed by the caller so the
/// spot overlay lines up exactly.
class VolleyballCourtPainter extends CustomPainter {
  final Rect courtRect;
  final Rect sidelineRect;

  /// The 3 m attack lines. Off for the compact preview, where they would
  /// run straight through the front-row players.
  final bool showAttackLines;

  /// How far the net (and its posts) reaches past each sideline.
  final double netOverhang;

  /// The free-zone floor around the court. Off when the court sits on a
  /// host panel that supplies its own background.
  final bool paintFreeZone;

  const VolleyballCourtPainter({
    required this.courtRect,
    required this.sidelineRect,
    this.showAttackLines = true,
    this.netOverhang = 12,
    this.paintFreeZone = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    // Free zone: a soft radial falloff so the court reads as lit from above.
    if (paintFreeZone) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds, const Radius.circular(22)),
        Paint()
          ..shader = const RadialGradient(
            radius: 0.9,
            colors: [AppColors.courtFreeZone, AppColors.courtFreeZoneDeep],
          ).createShader(bounds),
      );
    }

    // Bench strip along the sideline (absent when there are no subs).
    if (!sidelineRect.isEmpty) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(sidelineRect, const Radius.circular(16)),
        Paint()..color = AppColors.navyDeep.withValues(alpha: 0.35),
      );
    }

    _paintCourt(canvas);
    _paintNet(canvas);
  }

  void _paintCourt(Canvas canvas) {
    // Soft drop shadow lifts the court off the floor.
    canvas.drawRect(
      courtRect.shift(const Offset(0, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawRect(
      courtRect,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.8,
          colors: [AppColors.courtSurface, AppColors.courtSurfaceEdge],
        ).createShader(courtRect),
    );

    // Faint floorboards.
    final plank = Paint()
      ..color = AppColors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    final step = courtRect.width / 9;
    for (var x = courtRect.left + step; x < courtRect.right - 1; x += step) {
      canvas.drawLine(
          Offset(x, courtRect.top), Offset(x, courtRect.bottom), plank);
    }

    final line = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(courtRect, line);

    // Attack lines 3 m either side of the centre line (court is 18 m long).
    final centerY = courtRect.center.dy;
    if (showAttackLines) {
      final attack = courtRect.height / 6;
      for (final y in [centerY - attack, centerY + attack]) {
        canvas.drawLine(
            Offset(courtRect.left, y), Offset(courtRect.right, y), line);
      }
    }
    canvas.drawLine(Offset(courtRect.left, centerY),
        Offset(courtRect.right, centerY), line);
  }

  void _paintNet(Canvas canvas) {
    final centerY = courtRect.center.dy;
    final netRect = Rect.fromLTRB(
      courtRect.left - netOverhang,
      centerY - 6,
      courtRect.right + netOverhang,
      centerY + 6,
    );

    // Shadow the net casts onto the court.
    canvas.drawRect(
      netRect.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Mesh body.
    canvas.drawRect(
      netRect,
      Paint()..color = AppColors.navyDeep.withValues(alpha: 0.55),
    );
    final mesh = Paint()
      ..color = AppColors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var x = netRect.left + 4; x < netRect.right; x += 6) {
      canvas.drawLine(Offset(x, netRect.top), Offset(x, netRect.bottom), mesh);
    }
    canvas.drawLine(Offset(netRect.left, centerY),
        Offset(netRect.right, centerY), mesh);

    // White top and bottom tape.
    final tape = Paint()..color = AppColors.white;
    canvas.drawRect(
        Rect.fromLTWH(netRect.left, netRect.top, netRect.width, 2.5), tape);
    canvas.drawRect(
        Rect.fromLTWH(netRect.left, netRect.bottom - 1.5, netRect.width, 1.5),
        tape);

    // Posts just outside the sidelines.
    final post = Paint()..color = AppColors.white;
    final postRim = Paint()
      ..color = AppColors.navyDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final x in [netRect.left, netRect.right]) {
      canvas.drawCircle(Offset(x, centerY), 5, post);
      canvas.drawCircle(Offset(x, centerY), 5, postRim);
    }
  }

  @override
  bool shouldRepaint(VolleyballCourtPainter old) =>
      old.courtRect != courtRect ||
      old.sidelineRect != sidelineRect ||
      old.showAttackLines != showAttackLines ||
      old.netOverhang != netOverhang ||
      old.paintFreeZone != paintFreeZone;
}
