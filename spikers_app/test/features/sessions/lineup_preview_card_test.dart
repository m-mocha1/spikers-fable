import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spikers_app/core/theme/app_theme.dart';
import 'package:spikers_app/features/sessions/data/datasources/sessions_remote_datasource.dart';
import 'package:spikers_app/features/sessions/data/repositories/sessions_repository_impl.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import 'package:spikers_app/features/sessions/domain/lineup.dart';
import 'package:spikers_app/features/sessions/presentation/providers/sessions_providers.dart';
import 'package:spikers_app/features/sessions/presentation/widgets/lineup/lineup_preview_card.dart';
import 'package:spikers_app/l10n/app_localizations.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

/// The preview sits on the session screen for everyone, so it must lay out
/// cleanly on a phone-width card and show only the two starting sixes.
void main() {
  late FakeFirebaseFirestore db;
  late SessionsRepositoryImpl repo;
  final ids = [for (var i = 0; i < 14; i++) 'p$i'];

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = SessionsRepositoryImpl(SessionsRemoteDataSource(db, _MockFunctions()));
    final start = DateTime.now().add(const Duration(hours: 1));
    await db.collection('sessions').doc('s1').set({
      'title': 's1',
      'location': 'hall',
      'gender': 'mixed',
      'minAge': 0,
      'maxAge': 99,
      'startTime': Timestamp.fromDate(start),
      'endTime': Timestamp.fromDate(start.add(const Duration(hours: 2))),
      'maxPlayers': 20,
      'coachId': 'c1',
      'attendeeIds': ids,
      'createdAt': Timestamp.fromDate(DateTime(2026)),
    });
    for (final id in ids) {
      await db.collection('users_public').doc(id).set({'name': 'Name$id'});
    }
  });

  Future<void> pump(WidgetTester tester) async {
    final session =
        SessionModel.fromDoc(await db.collection('sessions').doc('s1').get());
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionsRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: LineupPreviewCard(session: session),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows both starting sixes but not the subs', (tester) async {
    // A 360dp-wide phone.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final lineup = Lineup.empty()
        .reconcile(ids)
        .move('p0', const LineupSlot(LineupArea.teamA, 0))
        .move('p1', const LineupSlot(LineupArea.teamB, 0))
        .move('p2', const LineupSlot(LineupArea.bench, 0));
    await repo.saveLineup('s1', lineup, 'c1');

    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Namep0'), findsOneWidget);
    expect(find.text('Namep1'), findsOneWidget);
    expect(find.text('Namep2'), findsNothing); // sub
  });

  testWidgets('renders an empty court before any line-up is saved',
      (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(LineupPreviewCard), findsOneWidget);
  });
}
