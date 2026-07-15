import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spikers_app/features/players/application/attendance_export.dart';
import 'package:spikers_app/features/players/domain/entities/player_summary.dart';
import 'package:spikers_app/features/players/presentation/providers/export_options_provider.dart';
import 'package:spikers_app/features/players/presentation/providers/players_providers.dart';
import 'package:spikers_app/features/players/presentation/screens/export_options_screen.dart';
import 'package:spikers_app/l10n/app_localizations.dart';

PlayerSummary _player(String name, String? gender) => PlayerSummary(
      uid: name,
      name: name,
      gender: gender,
      photoUrl: '',
      dateOfBirth: null,
      createdAt: null,
      attendanceCount: 0,
      paidUntil: null,
      lifetimeMember: false,
      injured: false,
    );

void main() {
  // One of each bucket, plus a player who never set a gender.
  final roster = [
    _player('Adam', 'male'),
    _player('Maya', 'female'),
    _player('Zoe', 'female'),
    _player('Nemo', null),
  ];

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playersProvider.overrideWith((ref) => Stream.value(roster)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExportOptionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to all genders and every column ticked',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('4 players will be exported'), findsOneWidget);
    final boxes = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(boxes, hasLength(ExportColumn.values.length));
    expect(boxes.every((b) => b.value == true), isTrue);
  });

  testWidgets('gender filter narrows the export count', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();
    expect(find.text('2 players will be exported'), findsOneWidget);

    // Nemo has no gender, so he is only in scope under "All" — never counted
    // as male.
    await tester.tap(find.text('Male'));
    await tester.pumpAndSettle();
    expect(find.text('1 player will be exported'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('4 players will be exported'), findsOneWidget);
  });

  testWidgets('unticking a column persists it to prefs', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Age'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
        tester.element(find.byType(ExportOptionsScreen)));
    expect(container.read(exportOptionsProvider).columns,
        isNot(contains(ExportColumn.age)));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('export_columns'),
        isNot(contains(ExportColumn.age.name)));
  });

  testWidgets('restores saved gender and columns from prefs', (tester) async {
    SharedPreferences.setMockInitialValues({
      'export_gender': 'male',
      'export_columns': [ExportColumn.lastPaid.name],
    });
    await pumpScreen(tester);

    expect(find.text('1 player will be exported'), findsOneWidget);
    final boxes =
        tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(boxes.where((b) => b.value == true), hasLength(1));
  });
}
