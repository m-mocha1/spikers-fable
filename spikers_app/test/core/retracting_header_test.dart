import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/core/widgets/retracting_header.dart';

// The header collapses once the list has travelled far enough in one direction
// — distance, not bare direction, so a twitch of a finger can't hide it. These
// tests pin both halves of that: a real swipe still retracts on the first try
// from a standing start, and a small one leaves the header alone.
void main() {
  const headerHeight = 80.0;

  Widget wrap({int rows = 50}) => MaterialApp(
        home: Scaffold(
          body: RetractingHeader(
            header: const SizedBox(height: headerHeight, child: Text('header')),
            child: ListView.builder(
              itemCount: rows,
              itemBuilder: (_, i) => SizedBox(height: 60, child: Text('row $i')),
            ),
          ),
        ),
      );

  /// Current rendered height of the collapsing block.
  double headerOf(WidgetTester tester) =>
      tester.getSize(find.byType(SizeTransition)).height;

  testWidgets('retracts on the first drag from a standing start at the top',
      (tester) async {
    await tester.pumpWidget(wrap());
    expect(headerOf(tester), headerHeight);

    // One drag, from rest at offset 0 — a deliberate swipe should not have to
    // be repeated to be obeyed.
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(headerOf(tester), 0);
  });

  testWidgets('a nudge too small to be deliberate leaves the header alone',
      (tester) async {
    await tester.pumpWidget(wrap());

    // Short of the retract distance: the list scrolls, the chrome holds still.
    await tester.drag(find.byType(ListView), const Offset(0, -30));
    await tester.pumpAndSettle();

    expect(headerOf(tester), headerHeight);
  });

  testWidgets('a jittery drag never starts the header moving', (tester) async {
    // Direction alone would flip on every leg here, flickering the header. The
    // finger never travels far enough one way to mean it, so the header must
    // hold still *throughout* — checking only where it ends up would pass on
    // the flicker, since the last leg leaves it open anyway.
    await tester.pumpWidget(wrap());

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(ListView)));
    for (var i = 0; i < 4; i++) {
      for (final leg in const [Offset(0, -40), Offset(0, 40)]) {
        await gesture.moveBy(leg);
        // Two frames, and the second one carrying real time: the tick that
        // starts an AnimationController anchors its clock and elapses nothing,
        // so a single pump reads 1.0 however long it claims to be — and the
        // flicker this test exists to catch would slip through unseen.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(headerOf(tester), headerHeight);
      }
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(headerOf(tester), headerHeight);
  });

  testWidgets('returns when the list scrolls back up', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(headerOf(tester), 0);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(headerOf(tester), headerHeight);
  });

  testWidgets('a list too short to scroll never retracts the header',
      (tester) async {
    // Nothing to scroll means nothing could bring the header back, so a drag
    // here must leave it alone.
    await tester.pumpWidget(wrap(rows: 1));
    expect(headerOf(tester), headerHeight);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(headerOf(tester), headerHeight);
  });

  testWidgets('ignores horizontal scrolls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetractingHeader(
            header: const SizedBox(height: headerHeight, child: Text('header')),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < 30; i++)
                  SizedBox(width: 100, child: Text('col $i')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(headerOf(tester), headerHeight);
  });
}
