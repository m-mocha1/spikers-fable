import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spikers_app/core/theme/app_theme.dart';
import 'package:spikers_app/core/widgets/branded_button.dart';
import 'package:spikers_app/features/players/presentation/widgets/membership_sheet.dart';
import 'package:spikers_app/l10n/app_localizations.dart';

/// The sheet's expiry preview duplicates the datasource's stacking rule, so it
/// gets its own guard: a coach must see the same total the write will produce.
void main() {
  Future<void> openSheet(WidgetTester tester, {DateTime? paidUntil}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          // The sheet reads the AppSemanticColors theme extension.
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showMembershipSheet(
                  context,
                  uid: 'p1',
                  name: 'Ahmad',
                  paidUntil: paidUntil,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('added days stack on top of the days already left',
      (tester) async {
    await openSheet(tester,
        paidUntil: DateTime.now().add(const Duration(days: 10)));

    expect(find.text('Active · 10 days left'), findsOneWidget);
    // 30 is the default preset: 10 left + 30 = 40.
    expect(find.text('40 days total'), findsOneWidget);
    expect(find.text('Add 30 days'), findsOneWidget);

    await tester.tap(find.text('14d'));
    await tester.pumpAndSettle();
    expect(find.text('24 days total'), findsOneWidget);
    expect(find.text('Add 14 days'), findsOneWidget);
  });

  testWidgets('removing days counts down from what is left', (tester) async {
    await openSheet(tester,
        paidUntil: DateTime.now().add(const Duration(days: 30)));

    await tester.tap(find.text('Remove days'));
    await tester.pumpAndSettle();

    // 30 left − 30 would wipe it, so the preview says so instead of showing a
    // date the write will never store.
    expect(find.text('Membership will end'), findsOneWidget);
    expect(find.text('Remove 30 days'), findsOneWidget);

    await tester.tap(find.text('7d'));
    await tester.pumpAndSettle();
    expect(find.text('23 days total'), findsOneWidget);
    expect(find.text('Remove 7 days'), findsOneWidget);
  });

  testWidgets('an expired membership restarts from today', (tester) async {
    await openSheet(tester,
        paidUntil: DateTime.now().subtract(const Duration(days: 5)));

    expect(find.text('Inactive'), findsOneWidget);
    expect(find.text('30 days total'), findsOneWidget);
    // Nothing to deactivate — or to take back — when it already lapsed.
    expect(find.text('Deactivate membership'), findsNothing);
    expect(find.text('Remove days'), findsNothing);
  });

  testWidgets('an out-of-range custom value blocks the CTA', (tester) async {
    await openSheet(tester, paidUntil: null);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '400');
    await tester.pumpAndSettle();

    expect(find.text('Enter 1–365 days'), findsOneWidget);
    expect(tester.widget<BrandedButton>(find.byType(BrandedButton)).onPressed,
        isNull);

    await tester.enterText(find.byType(TextFormField), '45');
    await tester.pumpAndSettle();

    expect(find.text('45 days total'), findsOneWidget);
    expect(tester.widget<BrandedButton>(find.byType(BrandedButton)).onPressed,
        isNotNull);
  });
}
