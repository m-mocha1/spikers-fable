import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import 'package:spikers_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:spikers_app/features/sessions/data/datasources/sessions_remote_datasource.dart';
import 'package:spikers_app/features/sessions/data/repositories/sessions_repository_impl.dart';
import 'package:spikers_app/features/sessions/presentation/providers/sessions_providers.dart';
import 'package:spikers_app/features/sessions/presentation/screens/lineup_screen.dart';
import 'package:spikers_app/l10n/app_localizations.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

/// The court used to collapse to nothing when the screen was short (phone
/// landscape, split screen): it must keep a usable size and scroll instead.
void main() {
  testWidgets('a coach editing on a short landscape screen lays out cleanly',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1080); // landscape phone
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = FakeFirebaseFirestore();
    final repo =
        SessionsRepositoryImpl(SessionsRemoteDataSource(db, _MockFunctions()));
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
      'attendeeIds': [for (var i = 0; i < 16; i++) 'p$i'],
      'createdAt': Timestamp.fromDate(DateTime(2026)),
    });
    final coach = UserModel(
      uid: 'c1',
      name: 'Coach',
      role: 'coach',
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionsRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWith((ref) => Stream.value(coach)),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LineupScreen(sessionId: 's1'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The board falls back to a scrollable page with a usable court.
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
