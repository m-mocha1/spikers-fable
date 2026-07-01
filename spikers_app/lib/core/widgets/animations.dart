import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_motion.dart';

/// Reusable animation building blocks shared across the app.
///
/// Screens compose these instead of hand-rolling `AnimationController`s, so
/// entrance motion, list staggering, and press feedback look identical
/// everywhere. Timing comes from [AppMotion].

/// Fades + lifts a widget into place, playing the entrance **once** when the
/// widget first mounts.
///
/// Crucially it does NOT replay on rebuild: the owning [AnimationController] is
/// already completed after the first play, so screens driven by live Firestore
/// streams / `setState` (lists, profile, session detail) reveal smoothly the
/// first time and then stay put as data updates — no more re-cascading on every
/// emission. Use for headers, single cards, and the children of a [Column] that
/// should reveal on screen entry.
class AppFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Vertical offset (as a fraction of the child's height) to slide up from.
  /// Set to 0 for a pure fade.
  final double slide;

  const AppFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.normal,
    this.slide = 0.12,
  });

  @override
  State<AppFadeIn> createState() => _AppFadeInState();
}

class _AppFadeInState extends State<AppFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curved =
      CurvedAnimation(parent: _controller, curve: AppMotion.enter);
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _startTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, widget.slide),
          end: Offset.zero,
        ).animate(_curved),
        child: widget.child,
      ),
    );
  }
}

/// Staggered entrance for the row at [index] in a list. The first rows cascade
/// in one after another ([AppMotion.staggerFor]) with the same fade + slide-up
/// used for the section reveals on the detail and profile screens, so lists and
/// detail pages share one motion language.
///
/// Because it builds on the play-once [AppFadeIn], the cascade runs **once** on
/// first mount and never re-cascades when the backing stream re-emits. Pass a
/// stable [key] at the call site (e.g. `ValueKey(model.id)`) so that after a
/// data update only genuinely-new rows animate; existing rows keep their
/// already-completed animation state and stay put.
class AppStaggeredItem extends StatelessWidget {
  final int index;
  final Widget child;
  final double slide;

  const AppStaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.slide = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    return AppFadeIn(
      delay: AppMotion.staggerFor(index),
      slide: slide,
      child: child,
    );
  }
}

/// Wraps any tappable surface with a tactile scale-down on press. Use around
/// cards, list rows, and custom buttons for physical-feeling feedback.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// Scale applied while the finger is down.
  final double pressedScale;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => _setDown(true),
      onTapUp: widget.onTap == null ? null : (_) => _setDown(false),
      onTapCancel: widget.onTap == null ? null : () => _setDown(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.press,
        child: widget.child,
      ),
    );
  }
}

/// Gentle infinite pulse — for "LIVE" badges and other attention cues.
class Pulse extends StatelessWidget {
  final Widget child;
  final double minScale;
  final double maxScale;

  const Pulse({
    super.key,
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 1.08,
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: minScale,
          end: maxScale,
          duration: AppMotion.pulse,
          curve: AppMotion.ambient,
        );
  }
}

/// Soft up-and-down float — used to bring static illustration icons (empty /
/// error states) to life.
class Floating extends StatelessWidget {
  final Widget child;
  final double distance;

  const Floating({super.key, required this.child, this.distance = 8});

  @override
  Widget build(BuildContext context) {
    return child
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
          begin: -distance / 2,
          end: distance / 2,
          duration: const Duration(milliseconds: 1800),
          curve: AppMotion.ambient,
        );
  }
}
