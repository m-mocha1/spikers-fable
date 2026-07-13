import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../constants/app_motion.dart';

/// Pins [header] above a scrollable [child] and retracts the header out of view
/// as the user scrolls the list down, revealing it again when they scroll back
/// up — reclaiming the vertical space a pinned header would otherwise hold
/// permanently.
///
/// The header collapses *upward* (like an app bar sliding away) and the list
/// grows into the freed space. This only animates the header's height in
/// response to the list's scroll direction — nothing about the header or list
/// content changes — so it drops in around any existing "header above a list"
/// screen: hand it the current header block and its `ListView`/scrollable.
class RetractingHeader extends StatefulWidget {
  const RetractingHeader({
    super.key,
    required this.header,
    required this.child,
  });

  /// The pinned block to retract (e.g. a search field + filter chips).
  final Widget header;

  /// The scrollable whose vertical scroll direction drives the retract.
  final Widget child;

  @override
  State<RetractingHeader> createState() => _RetractingHeaderState();
}

class _RetractingHeaderState extends State<RetractingHeader>
    with SingleTickerProviderStateMixin {
  // 1.0 == header fully shown, 0.0 == fully retracted.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
    value: 1,
  );

  late final Animation<double> _sizeFactor = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.ambient,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onScroll(UserScrollNotification n) {
    // Ignore horizontal scrolls (filter-chip rows, facepiles) — only the
    // vertical list should drive the header.
    if (n.metrics.axis != Axis.vertical) return false;

    // Always reveal when the list is at (or overscrolled past) the top, so the
    // header can never be stranded off-screen with nothing left to scroll up to.
    if (n.metrics.pixels <= n.metrics.minScrollExtent) {
      _controller.forward();
      return false;
    }

    switch (n.direction) {
      case ScrollDirection.reverse: // finger up, reading further down → hide.
        _controller.reverse();
        break;
      case ScrollDirection.forward: // finger down, heading back up → show.
        _controller.forward();
        break;
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizeTransition(
          sizeFactor: _sizeFactor,
          axisAlignment: -1, // collapse toward the top edge.
          child: widget.header,
        ),
        Expanded(
          child: NotificationListener<UserScrollNotification>(
            onNotification: _onScroll,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
