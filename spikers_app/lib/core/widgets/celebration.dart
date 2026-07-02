import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_gradients.dart';

/// Plays a one-shot celebratory burst — radiating gold rings, particles flying
/// outward, and a check that pops in — centered on the screen, then removes
/// itself (~1.2s). Non-blocking: it lives in the root [Overlay] above the
/// current route and ignores pointer events, so the user can keep interacting.
///
/// Dependency-free (plain [AnimationController] + [CustomPainter]) so it works
/// anywhere without adding a confetti package.
void showCelebration(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CelebrationBurst(onDone: entry.remove),
  );
  overlay.insert(entry);
}

class _CelebrationBurst extends StatefulWidget {
  final VoidCallback onDone;
  const _CelebrationBurst({required this.onDone});

  @override
  State<_CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<_CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
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
      color: rnd.nextBool() ? AppColors.gold : AppColors.white,
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
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            return CustomPaint(
              painter: _BurstPainter(progress: t, particles: _particles),
              child: SizedBox(
                width: 240,
                height: 240,
                child: Center(child: _check(t)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _check(double t) {
    // Pops in over the first 45%, holds, then fades out at the very end.
    final pop = Curves.easeOutBack.transform((t / 0.45).clamp(0.0, 1.0));
    final fade =
        t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0);
    return Opacity(
      opacity: fade,
      child: Transform.scale(
        scale: pop,
        child: Container(
          width: 74,
          height: 74,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.goldCta,
            boxShadow: [
              BoxShadow(color: Color(0x55FFB700), blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.check_rounded,
              color: AppColors.navyBlue, size: 44),
        ),
      ),
    );
  }
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
  _BurstPainter({required this.progress, required this.particles});

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
        ..color = AppColors.gold.withValues(alpha: (1 - rt) * 0.5);
      canvas.drawCircle(center, radius, paint);
    }

    // Particles fly outward (decelerating) and fade.
    final pt = Curves.easeOut.transform(progress);
    final opacity = (1 - progress).clamp(0.0, 1.0);
    for (final p in particles) {
      final dist = p.distance * pt;
      final pos = center +
          Offset(math.cos(p.angle) * dist, math.sin(p.angle) * dist);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.drawCircle(pos, p.size * (1 - progress * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.progress != progress;
}
