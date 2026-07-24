import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spikers_app/core/constants/app_assets.dart';
import 'package:spikers_app/features/sessions/data/datasources/sessions_remote_datasource.dart';
import 'package:spikers_app/features/sessions/data/repositories/player_groups_repository_impl.dart';
import 'package:spikers_app/features/sessions/data/repositories/session_chat_repository_impl.dart';
import 'package:spikers_app/features/sessions/data/repositories/sessions_repository_impl.dart';
import 'package:spikers_app/features/sessions/domain/repositories/sessions_repository.dart';
import 'package:spikers_app/features/sessions/domain/entities/player_group_model.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
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
      List<String> memberIds = const [],
      Duration startsIn = const Duration(hours: 1)}) async {
    final start = DateTime.now().add(startsIn);
    await db.collection('sessions').doc(id).set({
      'title': id,
      'location': 'hall',
      'gender': gender,
      'minAge': minAge,
      'maxAge': maxAge,
      'memberIds': memberIds,
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

  group('custom (members-only) session visibility', () {
    test('a listed member sees the custom session', () async {
      await seedSession('custom-s', memberIds: ['u1']);
      final list = await repo.watchUpcoming(user(), emailVerified: true).first;
      expect(list.map((s) => s.title), ['custom-s']);
    });

    test('a non-member player does not see the custom session', () async {
      await seedSession('public-mixed');
      await seedSession('custom-s', memberIds: ['someone-else']);
      final list = await repo.watchUpcoming(user(), emailVerified: true).first;
      expect(list.map((s) => s.title), ['public-mixed']);
    });

    test('coaches see custom sessions they are not a member of', () async {
      await seedSession('custom-s', memberIds: ['someone-else']);
      final list = await repo
          .watchUpcoming(user(role: 'coach', paid: false), emailVerified: true)
          .first;
      expect(list.map((s) => s.title), ['custom-s']);
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

  group('fetchAttendedSessions', () {
    Future<void> seedHistory(String id, DateTime start,
        {List<String> attendedIds = const ['u1', 'u2']}) async {
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

    test('returns full models with the roster preserved', () async {
      await seedHistory('h1', DateTime(2026, 6, 1, 18),
          attendedIds: ['u1', 'u2', 'u3']);
      await seedHistory('other', DateTime(2026, 6, 8, 18),
          attendedIds: ['someone-else']);

      final sessions = await repo.fetchAttendedSessions('u1');
      expect(sessions.map((s) => s.id), ['h1']);
      expect(sessions.single.title, 'h1');
      expect(sessions.single.attendedIds, ['u1', 'u2', 'u3']);
      expect(sessions.single.endTime, DateTime(2026, 6, 1, 20));
    });

    test('includes not-yet-archived live sessions the user attended',
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

      final ids = (await repo.fetchAttendedSessions('u1')).map((s) => s.id);
      expect(ids, containsAll(['h1', 'live1']));
    });

    test('empty when the user never attended', () async {
      await seedHistory('h1', DateTime(2026, 6, 1, 18),
          attendedIds: ['someone-else']);
      expect(await repo.fetchAttendedSessions('u1'), isEmpty);
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

  group('custom-session mutations', () {
    test('makeSessionPublic calls the callable with gender/age args',
        () async {
      final callable = _MockCallable();
      Map<String, dynamic>? sent;
      when(() => callable.call<dynamic>(any())).thenAnswer((invocation) async {
        sent = invocation.positionalArguments.first as Map<String, dynamic>;
        return _FakeResult({'success': true});
      });
      when(() => fns.httpsCallable('makeSessionPublic')).thenReturn(callable);

      await repo.makeSessionPublic('s1', gender: 'female', minAge: 18, maxAge: 30);

      expect(sent, {
        'sessionId': 's1',
        'gender': 'female',
        'minAge': 18,
        'maxAge': 30,
      });
    });

    test('updateSessionMembers calls the callable with the member list',
        () async {
      final callable = _MockCallable();
      Map<String, dynamic>? sent;
      when(() => callable.call<dynamic>(any())).thenAnswer((invocation) async {
        sent = invocation.positionalArguments.first as Map<String, dynamic>;
        return _FakeResult({'success': true});
      });
      when(() => fns.httpsCallable('updateSessionMembers')).thenReturn(callable);

      await repo.updateSessionMembers('s1', ['u2', 'u3']);

      expect(sent, {
        'sessionId': 's1',
        'memberIds': ['u2', 'u3'],
      });
    });

    test('wraps FirebaseFunctionsException into SessionActionException',
        () async {
      final callable = _MockCallable();
      when(() => callable.call<dynamic>(any())).thenThrow(
          FirebaseFunctionsException(
              message: 'not your session', code: 'permission-denied'));
      when(() => fns.httpsCallable('makeSessionPublic')).thenReturn(callable);

      await expectLater(
        repo.makeSessionPublic('s1', gender: 'mixed', minAge: 0, maxAge: 99),
        throwsA(isA<SessionActionException>()
            .having((e) => e.code, 'code', 'permission-denied')),
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

  group('profile cache', () {
    Future<void> seedProfile(String uid, String name,
            {int attendanceCount = 0}) =>
        db.collection('users_public').doc(uid).set({
          'name': name,
          'photoUrl': '',
          'gender': 'male',
          'attendanceCount': attendanceCount,
          'injured': false,
          'endorsementCount': 0,
        });

    test('cachedProfiles is empty before any fetch', () async {
      await seedProfile('u2', 'Two');
      expect(repo.cachedProfiles(['u2']), isEmpty);
    });

    test('fetchPublicProfiles populates the cache', () async {
      await seedProfile('u2', 'Two');
      await repo.fetchPublicProfiles(['u2']);
      expect(repo.cachedProfiles(['u2'])['u2']!.name, 'Two');
    });

    test('fetchPublicProfilesCached serves cached uids without re-querying',
        () async {
      await seedProfile('u2', 'Two');
      await seedProfile('u3', 'Three');
      await repo.fetchPublicProfiles(['u2']);
      // Deleting the doc proves a cache hit: a re-query couldn't find it.
      await db.collection('users_public').doc('u2').delete();

      final map = await repo.fetchPublicProfilesCached(['u2', 'u3']);
      expect(map['u2']!.name, 'Two');
      expect(map['u3']!.name, 'Three');
    });

    test('fetchPublicProfiles refreshes stale cache entries', () async {
      await seedProfile('u2', 'Two', attendanceCount: 1);
      await repo.fetchPublicProfiles(['u2']);
      await db
          .collection('users_public')
          .doc('u2')
          .update({'attendanceCount': 2});

      await repo.fetchPublicProfiles(['u2']);
      expect(repo.cachedProfiles(['u2'])['u2']!.attendanceCount, 2);
    });

    test('watchPublicProfile emissions feed the cache', () async {
      await seedProfile('u2', 'Two');
      await repo.watchPublicProfile('u2').first;
      expect(repo.cachedProfiles(['u2'])['u2']!.name, 'Two');
    });

    test('uids with no users_public doc are omitted and never cached',
        () async {
      expect(await repo.fetchPublicProfilesCached(['ghost']), isEmpty);
      // Absence must not be cached: once the doc exists it is found again.
      await seedProfile('ghost', 'Now Exists');
      final map = await repo.fetchPublicProfilesCached(['ghost']);
      expect(map['ghost']!.name, 'Now Exists');
    });
  });

  group('fetchPublicProfiles chunking', () {
    test('fetches more than 30 uids across parallel whereIn chunks',
        () async {
      final uids = List.generate(35, (i) => 'p$i');
      for (final uid in uids) {
        await db.collection('users_public').doc(uid).set({
          'name': 'name-$uid',
          'photoUrl': '',
        });
      }

      final map = await repo.fetchPublicProfiles(uids);
      expect(map, hasLength(35));
      expect(map['p34']!.name, 'name-p34');
    });

    test('empty uid list returns an empty map', () async {
      expect(await repo.fetchPublicProfiles([]), isEmpty);
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

  group('player groups repository (shared library)', () {
    test('save creates, updates, and delete removes', () async {
      final groups = PlayerGroupsRepositoryImpl(ds);
      await groups.save(PlayerGroup(
        id: '',
        name: 'Starters',
        memberIds: const ['p1', 'p2'],
        createdBy: 'c1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));

      var list = await groups.watch().first;
      expect(list.single.name, 'Starters');
      expect(list.single.memberIds, ['p1', 'p2']);
      expect(list.single.createdBy, 'c1');

      // Saving with the existing id updates in place (rename + new roster);
      // createdBy is preserved (toUpdateMap never rewrites it).
      final existing = list.single;
      await groups.save(PlayerGroup(
        id: existing.id,
        name: 'First Team',
        memberIds: const ['p1', 'p2', 'p3'],
        createdBy: existing.createdBy,
        createdAt: existing.createdAt,
        updatedAt: DateTime(2027),
      ));
      list = await groups.watch().first;
      expect(list.length, 1);
      expect(list.single.name, 'First Team');
      expect(list.single.memberIds, ['p1', 'p2', 'p3']);
      expect(list.single.createdBy, 'c1');

      await groups.delete(existing.id);
      list = await groups.watch().first;
      expect(list, isEmpty);
    });

    test('watch returns all coaches groups, updatedAt descending', () async {
      final groups = PlayerGroupsRepositoryImpl(ds);
      // Two different coaches — both visible in the one shared library.
      await groups.save(PlayerGroup(
        id: '',
        name: 'Older',
        memberIds: const ['p1'],
        createdBy: 'c1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ));
      await groups.save(PlayerGroup(
        id: '',
        name: 'Newer',
        memberIds: const ['p2'],
        createdBy: 'c2',
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      ));

      final list = await groups.watch().first;
      expect(list.map((g) => g.name), ['Newer', 'Older']);
    });
  });
}
