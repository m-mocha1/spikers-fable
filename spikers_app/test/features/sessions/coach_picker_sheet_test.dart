import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spikers_app/core/theme/app_theme.dart';
import 'package:spikers_app/core/widgets/branded_button.dart';
import 'package:spikers_app/features/coaches/domain/entities/coach_summary.dart';
import 'package:spikers_app/features/coaches/presentation/providers/coaches_providers.dart';
import 'package:spikers_app/features/sessions/presentation/widgets/coach_picker_sheet.dart';
import 'package:spikers_app/l10n/app_localizations.dart';

/// The picker is the only way a coach retags a session's available coaches
/// after creation, so its contract is guarded: it must open on the current
/// list, track toggles, and hand the caller exactly what was selected.
void main() {
  const coaches = [
    CoachSummary(uid: 'c1', name: 'Ahmad', photoUrl: ''),
    CoachSummary(uid: 'c2', name: 'Sara', photoUrl: ''),
    CoachSummary(uid: 'c3', name: 'Omar', photoUrl: ''),
  ];

  /// Pumps a host screen, opens the picker on [initial], and returns a getter
  /// for the sheet's outcome. [closed] distinguishes "dismissed with null"
  /// from "still open", which a bare null result cannot.
  Future<({bool closed, Set<String>? value}) Function()> open(
    WidgetTester tester, {
    required Set<String> initial,
  }) async {
    Set<String>? result;
    var closed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coachesProvider.overrideWith((ref) => Stream.value(coaches)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showCoachPicker(context, initial: initial);
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    return () => (closed: closed, value: result);
  }

  testWidgets('opens with the session\'s current coaches preselected',
      (tester) async {
    await open(tester, initial: {'c1', 'c3'});

    expect(find.text('Choose coaches'), findsOneWidget);
    // Header count reflects the incoming selection, not the roster size.
    expect(find.text('2 coaches'), findsOneWidget);
    for (final name in ['Ahmad', 'Sara', 'Omar']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('tapping a chip updates the selected count', (tester) async {
    await open(tester, initial: {'c1'});
    expect(find.text('1 coach'), findsOneWidget);

    await tester.tap(find.text('Sara'));
    await tester.pumpAndSettle();
    expect(find.text('2 coaches'), findsOneWidget);

    // Toggling the same chip again removes it.
    await tester.tap(find.text('Sara'));
    await tester.pumpAndSettle();
    expect(find.text('1 coach'), findsOneWidget);
  });

  testWidgets('Done pops the edited selection', (tester) async {
    final read = await open(tester, initial: {'c1'});

    await tester.tap(find.text('Omar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahmad')); // deselects the initial pick
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BrandedButton));
    await tester.pumpAndSettle();

    expect(read().value, {'c3'});
  });

  testWidgets('clearing every coach is allowed and pops an empty set',
      (tester) async {
    final read = await open(tester, initial: {'c1', 'c2'});

    await tester.tap(find.text('Ahmad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sara'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BrandedButton));
    await tester.pumpAndSettle();

    expect(read().value, isEmpty);
  });

  testWidgets('dismissing without confirming returns null', (tester) async {
    final read = await open(tester, initial: {'c1'});

    // Tap the scrim above the sheet.
    await tester.tapAt(const Offset(400, 40));
    await tester.pumpAndSettle();

    final outcome = read();
    expect(outcome.closed, isTrue, reason: 'the sheet should have closed');
    expect(outcome.value, isNull);
  });
}
