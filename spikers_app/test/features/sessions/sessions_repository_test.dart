import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spikers_app/core/constants/app_assets.dart';
import 'package:spikers_app/features/sessions/data/datasources/sessions_remote_datasource.dart';
import 'package:spikers_app/features/sessions/data/repositories/session_chat_repository_impl.dart';
import 'package:spikers_app/features/sessions/data/repositories/sessions_repository_impl.dart';
import 'package:spikers_app/features/sessions/data/repositories/templates_repository_impl.dart';
import 'package:spikers_app/features/sessions/domain/repositories/sessions_repository.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_template_model.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _FakeResult extends Fake implements HttpsCallableResult {
  @override
  final dynamic data;
  _FakeResult(this.data);
}

void main() {
  late FakeFirebaseFirestore db;
  late _MockFunctions fns;
  late SessionsRemoteDataSource ds;
  late SessionsRepositoryImpl repo;

  UserModel user({String role = 'player', bool paid = true}) => UserModel(
        uid: 'u1',
        name: 'U',
        gender: 'male',
        dateOfBirth: DateTime(2000),
        role: role,
        createdAt: DateTime(2026),
        paidUntil:
            paid ? DateTime.now().add(const Duration(days: 10)) : null,
      );

  Future<void> seedSession(String id,
      {String gender = 'mixed',
      int minAge = 0,
      int maxAge = 99,
      Duration startsIn = const Duration(hours: 1)}) async {
    final start = DateTime.now().add(startsIn);
    await db.collection('sessions').doc(id).set({
      'title': id,
      'location': 'hall',
      'gender': gender,
      'minAge': minAge,
      'maxAge': maxAge,
      'startTime': Timestamp.fromDate(start),
      'endTime': Timestamp.fromDate(start.add(const Duration(hours: 2))),
      'maxPlayers': 10,
      'coachId': 'c1',
      'attendeeIds': <String>[],
      'createdAt': Timestamp.fromDate(DateTime(2026)),
    });
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    fns = _MockFunctions();
    ds = SessionsRemoteDataSource(db, fns);
    repo = SessionsRepositoryImpl(ds);
  });

  group('watchUpcoming eligibility gates', () {
    test('unverified users get an empty list without querying', () async {
      await seedSession('s1');
      final list =
          await repo.watchUpcoming(user(), emailVerified: false).first;
      expect(list, isEmpty);
    });

    test('unpaid players get an empty list', () async {
      await seedSession('s1');
      final list = await repo
          .watchUpcoming(user(paid: false), emailVerified: true)
          .first;
      expect(list, isEmpty);
    });

    test('players with an incomplete profile get an empty list', () async {
      await seedSession('s1');
      final incomplete = UserModel(
        uid: 'u1',
        name: 'U',
        role: 'player',
        createdAt: DateTime(2026),
        paidUntil: DateTime.now().add(const Duration(days: 10)),
        // gender and dateOfBirth deliberately omitted
      );
      final list =
          await repo.watchUpcoming(incomplete, emailVerified: true).first;
      expect(list, isEmpty);
    });

    test('players see gender-matching sessions within their age range',
        () async {
      await seedSession('mixed-ok');
      await seedSession('female-only', gender: 'female');
      await seedSession('too-old', minAge: 40, maxAge: 60);

      final list =
          await repo.watchUpcoming(user(), emailVerified: true).first;
      expect(list.map((s) => s.title), ['mixed-ok']);
    });

    test('coaches see everything regardless of payment', () async {
      await seedSession('mixed-ok');
      await seedSession('female-only', gender: 'female');

      final list = await repo
          .watchUpcoming(user(role: 'coach', paid: false),
              emailVerified: true)
          .first;
      expect(list.length, 2);
    });
  });

  group('create card design assignment', () {
    SessionModel sessionAt(DateTime createdAt) => SessionModel(
          id: '',
          title: 'S',
          location: 'hall',
          gender: 'mixed',
          minAge: 0,
          maxAge: 99,
          startTime: DateTime(2026, 6, 1, 18),
          endTime: DateTime(2026, 6, 1, 20),
          maxPlayers: 10,
          coachId: 'c1',
          attendeeIds: const [],
          createdAt: createdAt,
        );

    test('never reuses the previous session\'s card twice in a row', () async {
      // Create a run of sessions with strictly increasing createdAt so the
      // "most recent session" lookup is deterministic, then verify no two
      // consecutive cards match and every index is in range.
      final base = DateTime(2026, 6, 1, 12);
      for (var i = 0; i < 30; i++) {
        await ds.create(sessionAt(base.add(Duration(minutes: i))));
      }

      final snap =
          await db.collection('sessions').orderBy('createdAt').get();
      final indices = snap.docs
          .map((d) => (d.data()['designIndex'] as num).toInt())
          .toList();

      expect(indices, hasLength(30));
      for (final idx in indices) {
        expect(idx, inInclusiveRange(0, AppAssets.cardDesigns.length - 1));
      }
      for (var i = 1; i < indices.length; i++) {
        expect(indices[i], isNot(indices[i - 1]),
            reason: 'session $i repeated the previous card');
      }
    });
  });

  group('watchHistory gender visibility', () {
    Future<void> seedHistorySession(String id,
        {String gender = 'mixed', required DateTime end}) async {
      await db.collection('sessions_history').doc(id).set({
        'title': id,
        'location': 'hall',
        'gender': gender,
        'minAge': 0,
        'maxAge': 99,
        'startTime': Timestamp.fromDate(end.subtract(const Duration(hours: 2))),
        'endTime': Timestamp.fromDate(end),
        'maxPlayers': 10,
        'coachId': 'c1',
        'attendeeIds': <String>[],
        'createdAt': Timestamp.fromDate(DateTime(2026)),
      });
    }

    test('players see only their own gender and mixed sessions', () async {
      await seedHistorySession('male-s',
          gender: 'male', end: DateTime(2026, 6, 3, 20));
      await seedHistorySession('female-s',
          gender: 'female', end: DateTime(2026, 6, 2, 20));
      await seedHistorySession('mixed-s', end: DateTime(2026, 6, 1, 20));

      final list = await repo.watchHistory(user()).first;
      expect(list.map((s) => s.title), ['male-s', 'mixed-s']);
    });

    test('coaches see all genders, most recently ended first', () async {
      await seedHistorySession('female-s',
          gender: 'female', end: DateTime(2026, 6, 2, 20));
      await seedHistorySession('male-s',
          gender: 'male', end: DateTime(2026, 6, 3, 20));
      await seedHistorySession('mixed-s', end: DateTime(2026, 6, 1, 20));

      final list = await repo.watchHistory(user(role: 'coach')).first;
      expect(list.map((s) => s.title), ['male-s', 'female-s', 'mixed-s']);
    });

    test('players without a gender on file are not filtered', () async {
      await seedHistorySession('female-s',
          gender: 'female', end: DateTime(2026, 6, 2, 20));
      final noGender = UserModel(
        uid: 'u1',
        name: 'U',
        role: 'player',
        createdAt: DateTime(2026),
      );
      final list = await repo.watchHistory(noGender).first;
      expect(list, hasLength(1));
    });
  });

  group('fetchAttendedTimes', () {
    Future<void> seedHistory(String id, DateTime start,
        {List<String> attendedIds = const ['u1']}) async {
      await db.collection('sessions_history').doc(id).set({
        'title': id,
        'location': 'hall',
        'gender': 'mixed',
        'minAge': 0,
        'maxAge': 99,
        'startTime': Timestamp.fromDate(start),
        'endTime': Timestamp.fromDate(start.add(const Duration(hours: 2))),
        'maxPlayers': 10,
        'coachId': 'c1',
        'attendeeIds': attendedIds,
        'attendedIds': attendedIds,
        'createdAt': Timestamp.fromDate(DateTime(2026)),
      });
    }

    test('returns start times from history where the user attended', () async {
      await seedHistory('h1', DateTime(2026, 6, 1, 18));
      await seedHistory('h2', DateTime(2026, 6, 8, 18));
      await seedHistory('other', DateTime(2026, 6, 15, 18),
          attendedIds: ['someone-else']);

      final times = await repo.fetchAttendedTimes('u1');
      expect(times, hasLength(2));
      expect(times, contains(DateTime(2026, 6, 1, 18)));
      expect(times, contains(DateTime(2026, 6, 8, 18)));
    });

    test('includes not-yet-archived live sessions the user attended',
        () async {
      await seedHistory('h1', DateTime(2026, 6, 1, 18));
      // A live session already marked attended (e.g. ongoing today).
      final liveStart = DateTime(2026, 6, 20, 18);
      await db.collection('sessions').doc('live1').set({
        'title': 'live1',
        'location': 'hall',
        'gender': 'mixed',
        'minAge': 0,
        'maxAge': 99,
        'startTime': Timestamp.fromDate(liveStart),
        'endTime':
            Timestamp.fromDate(liveStart.add(const Duration(hours: 2))),
        'maxPlayers': 10,
        'coachId': 'c1',
        'attendeeIds': ['u1'],
        'attendedIds': ['u1'],
        'createdAt': Timestamp.fromDate(DateTime(2026)),
      });

      final times = await repo.fetchAttendedTimes('u1');
      expect(times, hasLength(2));
      expect(times, contains(liveStart));
    });

    test('empty when the user never attended', () async {
      await seedHistory('h1', DateTime(2026, 6, 1, 18),
          attendedIds: ['someone-else']);
      expect(await repo.fetchAttendedTimes('u1'), isEmpty);
    });

    test('fetchLastAttendedTime returns the newest history start', () async {
      await seedHistory('h1', DateTime(2026, 6, 1, 18));
      await seedHistory('h2', DateTime(2026, 6, 8, 18));
      await seedHistory('other', DateTime(2026, 6, 15, 18),
          attendedIds: ['someone-else']);

      expect(await repo.fetchLastAttendedTime('u1'), DateTime(2026, 6, 8, 18));
    });

    test('fetchLastAttendedTime prefers a newer not-yet-archived live session',
        () async {
      await seedHistory('h1', DateTime(2026, 6, 1, 18));
      final liveStart = DateTime(2026, 6, 20, 18);
      await db.collection('sessions').doc('live1').set({
        'title': 'live1',
        'location': 'hall',
        'gender': 'mixed',
        'minAge': 0,
        'maxAge': 99,
        'startTime': Timestamp.fromDate(liveStart),
        'endTime':
            Timestamp.fromDate(liveStart.add(const Duration(hours: 2))),
        'maxPlayers': 10,
        'coachId': 'c1',
        'attendeeIds': ['u1'],
        'attendedIds': ['u1'],
        'createdAt': Timestamp.fromDate(DateTime(2026)),
      });

      expect(await repo.fetchLastAttendedTime('u1'), liveStart);
    });

    test('fetchLastAttendedTime is null when the user never attended',
        () async {
      await seedHistory('h1', DateTime(2026, 6, 1, 18),
          attendedIds: ['someone-else']);
      expect(await repo.fetchLastAttendedTime('u1'), isNull);
    });
  });

  group('join result/error mapping', () {
    HttpsCallable stubCall(dynamic result) {
      final callable = _MockCallable();
      when(() => callable.call<dynamic>(any()))
          .thenAnswer((_) async => _FakeResult(result));
      when(() => fns.httpsCallable('joinSession')).thenReturn(callable);
      return callable;
    }

    test('maps waitlisted status', () async {
      stubCall({'status': 'waitlisted'});
      expect(await repo.join('s1'), JoinResult.waitlisted);
    });

    test('maps already_joined status', () async {
      stubCall({'status': 'already_joined'});
      expect(await repo.join('s1'), JoinResult.alreadyJoined);
    });

    test('wraps FirebaseFunctionsException into SessionActionException',
        () async {
      final callable = _MockCallable();
      when(() => callable.call<dynamic>(any())).thenThrow(
          FirebaseFunctionsException(
              message: 'full', code: 'failed-precondition'));
      when(() => fns.httpsCallable('joinSession')).thenReturn(callable);

      await expectLater(
        repo.join('s1'),
        throwsA(isA<SessionActionException>()
            .having((e) => e.code, 'code', 'failed-precondition')),
      );
    });
  });

  group('endorse', () {
    test('calls the endorsePlayer callable on success', () async {
      final callable = _MockCallable();
      when(() => callable.call<dynamic>(any()))
          .thenAnswer((_) async => _FakeResult({'success': true}));
      when(() => fns.httpsCallable('endorsePlayer')).thenReturn(callable);

      await repo.endorse('s1', 'u2');

      verify(() => callable.call<dynamic>(any())).called(1);
    });

    test('wraps FirebaseFunctionsException into SessionActionException',
        () async {
      final callable = _MockCallable();
      when(() => callable.call<dynamic>(any())).thenThrow(
          FirebaseFunctionsException(
              message: 'did not attend', code: 'failed-precondition'));
      when(() => fns.httpsCallable('endorsePlayer')).thenReturn(callable);

      await expectLater(
        repo.endorse('s1', 'u2'),
        throwsA(isA<SessionActionException>()
            .having((e) => e.code, 'code', 'failed-precondition')),
      );
    });
  });

  group('watchMyEndorsements', () {
    test('emits only this session\'s endorsees for the given fromUid',
        () async {
      await db
          .collection('endorsements')
          .doc('s1_me_u2')
          .set({'sessionId': 's1', 'fromUid': 'me', 'toUid': 'u2'});
      await db
          .collection('endorsements')
          .doc('s1_me_u3')
          .set({'sessionId': 's1', 'fromUid': 'me', 'toUid': 'u3'});
      // Different session — excluded by the client-side sessionId filter.
      await db
          .collection('endorsements')
          .doc('s2_me_u4')
          .set({'sessionId': 's2', 'fromUid': 'me', 'toUid': 'u4'});
      // Another user's endorsement — excluded by the fromUid query.
      await db
          .collection('endorsements')
          .doc('s1_other_u2')
          .set({'sessionId': 's1', 'fromUid': 'other', 'toUid': 'u2'});

      final endorsed = await repo.watchMyEndorsements('s1', 'me').first;
      expect(endorsed, {'u2', 'u3'});
    });
  });

  group('fetchPublicProfiles endorsementCount', () {
    test('reads endorsementCount, defaulting to 0 when absent', () async {
      await db.collection('users_public').doc('u2').set({
        'name': 'Two',
        'photoUrl': '',
        'gender': 'male',
        'attendanceCount': 5,
        'injured': false,
        'endorsementCount': 3,
      });
      await db.collection('users_public').doc('u3').set({
        'name': 'Three',
        'gender': 'male',
      });

      final map = await repo.fetchPublicProfiles(['u2', 'u3']);
      expect(map['u2']!.endorsementCount, 3);
      expect(map['u3']!.endorsementCount, 0);
    });
  });

  group('chat repository', () {
    test('send + watchLatest round-trip, newest first', () async {
      final chat = SessionChatRepositoryImpl(ds);
      await chat.send('s1', senderId: 'u1', text: 'first');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await chat.send('s1', senderId: 'u2', text: 'second');

      final msgs = await chat.watchLatest('s1').first;
      expect(msgs.length, 2);
      expect(msgs.first.text, 'second');
      expect(msgs.last.senderId, 'u1');
    });
  });

  group('templates repository', () {
    test('save/watch/delete lifecycle', () async {
      final templates = TemplatesRepositoryImpl(ds);
      await templates.save(
          'c1',
          SessionTemplate(
            id: '',
            title: 'T',
            location: 'L',
            gender: 'mixed',
            minAge: 16,
            maxAge: 40,
            maxPlayers: 12,
            createdAt: DateTime(2026),
          ));

      var list = await templates.watch('c1').first;
      expect(list.single.title, 'T');

      await templates.delete('c1', list.single.id);
      list = await templates.watch('c1').first;
      expect(list, isEmpty);
    });
  });
}
