import 'package:flutter/material.dart';

/// Decides when a piece of chrome should hide while the user reads further down
/// a list and come back on the way up, driving [controller] (1 == fully shown,
/// 0 == fully retracted).
///
/// What actually collapses is the caller's business — [RetractingHeader] shrinks
/// a pinned block, the home shell shrinks its app bar and slides its nav bar out
/// — so one scroll gesture reads the same way everywhere.
///
/// Attach it with [RetractOnScroll]: two notification types have to be listened
/// for and only one of them is a [ScrollNotification].
class ScrollRetraction {
  ScrollRetraction(
    this.controller, {
    this.retractDistance = 72,
    this.revealDistance = 24,
  });

  /// 1 == fully shown, 0 == fully retracted.
  final AnimationController controller;

  /// How far the list has to travel in one direction before the chrome moves.
  ///
  /// Acting on direction alone makes a twitch of a finger — or the slop at the
  /// end of a fling — enough to hide the chrome, which reads as the screen
  /// flinching. Hiding is the disruptive half, so it asks for a deliberate
  /// swipe; bringing the chrome back is what the user wants when they reach for
  /// it, so [revealDistance] is short enough to feel immediate.
  final double retractDistance;
  final double revealDistance;

  /// Distance travelled since the last direction change: positive scrolling
  /// down the list, negative back up.
  double _drift = 0;

  // Re-calling forward/reverse mid-flight restarts the simulation with a
  // duration re-scaled to the remaining distance, which stutters — and
  // `ScrollUpdateNotification` fires every frame. So only act on a real change.
  void reveal() {
    if (controller.isCompleted ||
        controller.status == AnimationStatus.forward) {
      return;
    }
    controller.forward();
  }

  void retract() {
    if (controller.isDismissed ||
        controller.status == AnimationStatus.reverse) {
      return;
    }
    controller.reverse();
  }

  bool handleScroll(ScrollNotification n) {
    // Ignore horizontal scrolls (the home tab pager, filter-chip rows,
    // facepiles) — only the vertical list should drive the retract.
    if (n.metrics.axis != Axis.vertical) return false;

    // Each new gesture argues for itself: distance left over from the last one
    // must not count toward this one's threshold.
    if (n is ScrollStartNotification) _drift = 0;

    if (n is ScrollUpdateNotification) {
      final delta = n.scrollDelta ?? 0;
      if (delta != 0) {
        // A reversal starts the tally over, so crossing a threshold always
        // means "travelled this far *this way*" rather than netting out against
        // where the finger has already been.
        if (delta.sign != _drift.sign) _drift = 0;
        _drift += delta;
      }

      if (_drift >= retractDistance) {
        // A list too short to scroll can still be dragged (overscroll bounce);
        // retracting there would strand the chrome with nothing left to scroll
        // back up to.
        if (n.metrics.maxScrollExtent > 0) retract();
      } else if (_drift <= -revealDistance) {
        reveal();
      }
    }

    if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
      // Always reveal at (or overscrolled past) the top, so nothing can be
      // stranded off-screen — and no threshold gates this, since there is no
      // more list to ask the user to swipe through.
      if (n.metrics.pixels <= n.metrics.minScrollExtent) reveal();
    }
    return false;
  }

  bool handleMetrics(ScrollMetricsNotification n) {
    // A list that shrinks below the viewport (a filter narrowing the rows)
    // stops sending scroll notifications entirely — without this the chrome
    // would stay retracted with no way left to scroll it back into reach.
    if (n.metrics.axis == Axis.vertical && n.metrics.maxScrollExtent <= 0) {
      reveal();
    }
    return false;
  }
}

/// Feeds every scroll under [child] to [retraction].
///
/// Notifications keep bubbling past this, so nesting is fine and intended: a
/// tab's list drives both its own header and the home shell's bars.
class RetractOnScroll extends StatelessWidget {
  const RetractOnScroll({
    super.key,
    required this.retraction,
    required this.child,
  });

  final ScrollRetraction retraction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `ScrollMetricsNotification` is a sibling of `ScrollNotification`, not a
    // subclass, so it needs its own listener.
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: retraction.handleMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: retraction.handleScroll,
        child: child,
      ),
    );
  }
}
