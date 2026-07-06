import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_gradients.dart';

/// Plays a one-shot feedback burst — radiating rings, particles flying outward,
/// and a centerpiece that pops in — centered on the screen, then removes itself.
/// The centerpiece is an [icon] disc by default (a gold check), or the
/// [badgeAsset] image when one is given (used for tier promotions, which also
/// linger longer). [accent] tints the rings, particles, and disc so distinct
/// actions read differently (e.g. a muted grey logout for leaving a session).
/// Pass [grand] to give an icon centerpiece the promotion-style treatment — a
/// larger disc that lingers ~2.6s — used for the join/leave feedback.
/// Pass [dim] to darken the whole screen behind the burst (a black scrim that
/// fades in and out with it). Tier/level promotions ([badgeAsset]) dim
/// automatically; icon bursts opt in.
/// Non-blocking: it lives in the root [Overlay] above the current route and
/// ignores pointer events, so the user can keep interacting.
///
/// Dependency-free (plain [AnimationController] + [CustomPainter]) so it works
/// anywhere without adding a confetti package.
void showCelebration(
  BuildContext context, {
  String? badgeAsset,
  IconData icon = Icons.check_rounded,
  Color accent = AppColors.gold,
  bool grand = false,
  bool dim = false,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CelebrationBurst(
      onDone: entry.remove,
      badgeAsset: badgeAsset,
      icon: icon,
      accent: accent,
      grand: grand,
      dim: dim,
    ),
  );
  overlay.insert(entry);
}

class _CelebrationBurst extends StatefulWidget {
  final VoidCallback onDone;
  final String? badgeAsset;
  final IconData icon;
  final Color accent;
  final bool grand;
  final bool dim;
  const _CelebrationBurst({
    required this.onDone,
    this.badgeAsset,
    required this.icon,
    required this.accent,
    this.grand = false,
    this.dim = false,
  });

  @override
  State<_CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<_CelebrationBurst>
    with SingleTickerProviderStateMixin {
  // Tier-promotion badges and "grand" icon bursts linger; the lightweight
  // ticks (endorse) stay snappy.
  late final AnimationController _c =
      AnimationController(
          vsync: this,
          duration: Duration(
            milliseconds: (widget.badgeAsset != null || widget.grand)
                ? 2600
                : 1400,
          ),
        )
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        })
        ..forward();

  static const _particleCount = 14;
  late final List<_Particle> _particles = List.generate(_particleCount, (i) {
    final rnd = math.Random(i * 7 + 3);
    final angle = (i / _particleCount) * 2 * math.pi + rnd.nextDouble() * 0.4;
    final distance = 90 + rnd.nextDouble() * 70;
    final size = 5 + rnd.nextDouble() * 5;
    return _Particle(
      angle: angle,
      distance: distance,
      size: size,
      color: rnd.nextBool() ? widget.accent : AppColors.white,
    );
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // The rings/particles burst plays out in the first ~46% of the run
          // (keeping its original snappy ~1.2s pace) while the centerpiece
          // badge below holds visible for the remainder.
          final burst = (t / 0.46).clamp(0.0, 1.0);
          final burstWidget = Center(
            child: CustomPaint(
              painter: _BurstPainter(
                progress: burst,
                particles: _particles,
                accent: widget.accent,
              ),
              child: SizedBox(
                width: 240,
                height: 240,
                child: Center(child: _centerpiece(t)),
              ),
            ),
          );
          // Tier/level promotions (a [badgeAsset]) dim the whole screen behind
          // the badge so it reads as a "moment"; icon bursts dim only when they
          // opt in via [dim] (join/leave/endorse).
          if (widget.badgeAsset == null && !widget.dim) return burstWidget;
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: _scrimOpacity(t),
                child: const ColoredBox(color: Colors.black),
              ),
              burstWidget,
            ],
          );
        },
      ),
    );
  }

  /// Backdrop dimming for a promotion burst: fades in fast, holds through the
  /// badge, then fades out with it. Peaks below full black so the UI behind
  /// stays recognisable.
  double _scrimOpacity(double t) {
    const maxOpacity = 0.62;
    const fadeIn = 0.12;
    const fadeOutStart = 0.80;
    final double k;
    if (t < fadeIn) {
      k = t / fadeIn;
    } else if (t < fadeOutStart) {
      k = 1.0;
    } else {
      k = (1 - (t - fadeOutStart) / (1 - fadeOutStart)).clamp(0.0, 1.0);
    }
    return k * maxOpacity;
  }

  Widget _centerpiece(double t) {
    // Pops in quickly over the first ~20%, holds visible for most of the run,
    // then fades out over the last ~15% so the badge lingers on screen.
    final pop = Curves.easeOutBack.transform((t / 0.2).clamp(0.0, 1.0));
    final fade = t < 0.85 ? 1.0 : (1 - (t - 0.85) / 0.15).clamp(0.0, 1.0);
    return Opacity(
      opacity: fade,
      child: Transform.scale(
        scale: pop,
        child: widget.badgeAsset == null
            ? _medallion()
            : _badge(widget.badgeAsset!),
      ),
    );
  }

  /// Default centerpiece: an [accent]-tinted disc with the given [icon]. Gold
  /// keeps its signature gradient; other accents use a solid fill. [grand]
  /// scales it up (and up the halo) for the promotion-style join/leave burst.
  Widget _medallion() {
    final isGold = widget.accent == AppColors.gold;
    final size = widget.grand ? 112.0 : 74.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isGold ? AppGradients.goldCta : null,
        color: isGold ? null : widget.accent,
        boxShadow: [
          BoxShadow(
            color: widget.accent.withValues(alpha: widget.grand ? 0.45 : 0.33),
            blurRadius: widget.grand ? 30 : 20,
            spreadRadius: widget.grand ? 4 : 2,
          ),
        ],
      ),
      child: Icon(
        widget.icon,
        color: AppColors.navyBlue,
        size: widget.grand ? 62 : 44,
      ),
    );
  }

  /// Promotion centerpiece: the earned tier badge haloed in gold. Falls back to
  /// the check medallion if the art can't be loaded.
  Widget _badge(String asset) => DecoratedBox(
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: Color(0x55FFB700), blurRadius: 26, spreadRadius: 4),
      ],
    ),
    child: Image.asset(
      asset,
      width: 200,
      height: 200,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _medallion(),
    ),
  );
}

class _Particle {
  final double angle;
  final double distance;
  final double size;
  final Color color;
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  final Color accent;
  _BurstPainter({
    required this.progress,
    required this.particles,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    // Two expanding, fading rings.
    for (var r = 0; r < 2; r++) {
      final delay = r * 0.12;
      final rt = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      final radius = 30 + rt * 90;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - rt) + 1
        ..color = accent.withValues(alpha: (1 - rt) * 0.5);
      canvas.drawCircle(center, radius, paint);
    }

    // Particles fly outward (decelerating) and fade.
    final pt = Curves.easeOut.transform(progress);
    final opacity = (1 - progress).clamp(0.0, 1.0);
    for (final p in particles) {
      final dist = p.distance * pt;
      final pos =
          center + Offset(math.cos(p.angle) * dist, math.sin(p.angle) * dist);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.drawCircle(pos, p.size * (1 - progress * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.progress != progress;
}
