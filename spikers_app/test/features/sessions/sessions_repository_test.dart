import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spikers_app/features/sessions/data/datasources/sessions_remote_datasource.dart';
import 'package:spikers_app/features/sessions/data/repositories/session_chat_repository_impl.dart';
import 'package:spikers_app/features/sessions/data/repositories/sessions_repository_impl.dart';
import 'package:spikers_app/features/sessions/data/repositories/templates_repository_impl.dart';
import 'package:spikers_app/features/sessions/domain/repositories/sessions_repository.dart';
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
