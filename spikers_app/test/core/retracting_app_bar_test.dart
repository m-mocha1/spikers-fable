import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/core/widgets/retracting_app_bar.dart';
import 'package:spikers_app/core/widgets/scroll_retraction.dart';

// Mirrors how the home shell hangs its app bar and nav bar off one scroll: the
// app bar reclaims space by shrinking the height it asks the Scaffold for,
// while the nav bar (which the body already runs under) just translates away.
const statusBar = 24.0;
const navBarHeight = 56.0;

/// The default test surface — the nav bar's resting place is measured off it.
const screen = Size(800, 600);

/// The page route wrapping the harness slides too, so the nav bar has to be
/// found by identity rather than by type.
const navKey = Key('nav');

void main() {
  Widget wrap({int rows = 50}) => MaterialApp(
        home: Builder(
          // The whole point of shrinking `preferredSize` rather than the bar
          // itself is what the Scaffold adds on top of it, so the test is
          // meaningless without a status-bar inset to preserve.
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: const EdgeInsets.only(top: statusBar)),
            child: _Harness(rows: rows),
          ),
        ),
      );

  /// Height the app bar claims from the Scaffold, status-bar inset included.
  double barOf(WidgetTester tester) =>
      tester.getSize(find.byType(RetractingAppBar)).height;

  /// Top edge of the nav bar in screen coordinates — it slides rather than
  /// resizes, so its size never changes and only its position tells us.
  double navTopOf(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(navKey)).dy;

  double bodyOf(WidgetTester tester) =>
      tester.getSize(find.byType(ListView)).height;

  testWidgets('app bar hands the toolbar to the body but keeps the status band',
      (tester) async {
    await tester.pumpWidget(wrap());
    expect(barOf(tester), statusBar + kToolbarHeight);
    final restingBody = bodyOf(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    // The toolbar is gone, but the band under the system clock is not: rows
    // must never scroll up into it.
    expect(barOf(tester), statusBar);
    expect(bodyOf(tester), restingBody + kToolbarHeight);
  });

  testWidgets('nav bar slides clear of the bottom edge', (tester) async {
    await tester.pumpWidget(wrap());
    expect(navTopOf(tester), screen.height - navBarHeight);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(navTopOf(tester), screen.height);
  });

  testWidgets('both bars come back on the way up', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(barOf(tester), statusBar);

    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pumpAndSettle();

    expect(barOf(tester), statusBar + kToolbarHeight);
    expect(navTopOf(tester), screen.height - navBarHeight);
  });

  testWidgets('a list too short to scroll keeps both bars', (tester) async {
    await tester.pumpWidget(wrap(rows: 1));

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(barOf(tester), statusBar + kToolbarHeight);
    expect(navTopOf(tester), screen.height - navBarHeight);
  });
}

class _Harness extends StatefulWidget {
  const _Harness({required this.rows});

  final int rows;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: 1,
  );

  late final ScrollRetraction _bars = ScrollRetraction(_controller);

  late final Animation<Offset> _navSlide = Tween(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = RetractOnScroll(
      retraction: _bars,
      child: ListView.builder(
        itemCount: widget.rows,
        itemBuilder: (_, i) => SizedBox(height: 60, child: Text('row $i')),
      ),
    );

    final navBar = SlideTransition(
      position: _navSlide,
      child: const SizedBox(
        key: navKey,
        height: navBarHeight,
        width: double.infinity,
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => Scaffold(
        extendBody: true,
        appBar: RetractingAppBar(
          factor: _controller.value,
          bar: AppBar(title: const Text('title')),
        ),
        body: body,
        bottomNavigationBar: navBar,
      ),
    );
  }
}
