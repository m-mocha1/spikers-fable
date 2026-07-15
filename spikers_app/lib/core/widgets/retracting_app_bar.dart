import 'package:flutter/material.dart';

/// Wraps an app [bar] so it can retract out of a [Scaffold], giving the body
/// the toolbar's height back rather than leaving a gap where it used to be.
///
/// Only the toolbar goes: [Scaffold] adds the status-bar inset on top of
/// `preferredSize` itself, so at [factor] 0 the slot is exactly the status bar
/// and stays filled by the bar's own background — list rows never scroll under
/// the system clock.
///
/// [factor] is a plain value, not an [Animation], because [Scaffold] reads
/// `preferredSize` off the widget while *it* builds: animating this means
/// rebuilding the [Scaffold] each frame (e.g. from an [AnimatedBuilder]), and a
/// self-animating bar could not report its changing height to its parent.
class RetractingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RetractingAppBar({
    super.key,
    required this.factor,
    required this.bar,
  });

  /// 1 == fully shown, 0 == fully retracted.
  final double factor;

  final PreferredSizeWidget bar;

  @override
  Size get preferredSize => Size.fromHeight(bar.preferredSize.height * factor);

  @override
  Widget build(BuildContext context) {
    // The bar keeps its natural height and is clipped rather than squeezed:
    // laying an AppBar out shorter than its toolbar overflows its contents.
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minHeight: 0,
        maxHeight: double.infinity,
        child: bar,
      ),
    );
  }
}
