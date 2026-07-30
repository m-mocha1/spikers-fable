import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spikers_app/features/players/data/datasources/players_remote_datasource.dart';
import 'package:spikers_app/features/players/data/repositories/players_repository_impl.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockStorage extends Mock implements FirebaseStorage {}

void main() {
  late FakeFirebaseFirestore db;
  late PlayersRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = PlayersRepositoryImpl(
        PlayersRemoteDataSource(db, _MockFunctions(), _MockStorage()));
  });

  Future<void> seedPlayer(String uid, String name,
      {String gender = 'male', bool lifetime = false, bool injured = false}) async {
    await db.collection('users').doc(uid).set({
      'role': 'player',
      'name': name,
      'gender': gender,
      'lifetimeMember': lifetime,
      'injured': injured,
    });
  }

  group('watchPlayers', () {
    test('returns players name-sorted, excludes coaches', () async {
      await seedPlayer('b', 'Bilal');
      await seedPlayer('a', 'Aya', gender: 'female');
      await db
          .collection('users')
          .doc('c')
          .set({'role': 'coach', 'name': 'Coach'});

      final players = await repo.watchPlayers().first;
      expect(players.map((p) => p.name), ['Aya', 'Bilal']);
    });

    test('parses injured flag, defaulting to false when absent', () async {
      await seedPlayer('hurt', 'Hurt', injured: true);
      await db.collection('users').doc('ok').set({
        'role': 'player',
        'name': 'Ok',
        'gender': 'male',
      });

      final byUid = {for (final p in await repo.watchPlayers().first) p.uid: p};
      expect(byUid['hurt']!.injured, isTrue);
      expect(byUid['ok']!.injured, isFalse);
    });
  });

  group('watchPeers', () {
    test('same gender only, excludes self', () async {
      await db.collection('users_public').doc('me').set(
          {'role': 'player', 'name': 'Me', 'gender': 'male'});
      await db.collection('users_public').doc('p1').set(
          {'role': 'player', 'name': 'Peer', 'gender': 'male'});
      await db.collection('users_public').doc('p2').set(
          {'role': 'player', 'name': 'Other', 'gender': 'female'});

      final peers =
          await repo.watchPeers(myUid: 'me', myGender: 'male').first;
      expect(peers.length, 1);
      expect(peers.single.uid, 'p1');
    });

    test('parses injured flag from the public mirror', () async {
      await db.collection('users_public').doc('me').set(
          {'role': 'player', 'name': 'Me', 'gender': 'male'});
      await db.collection('users_public').doc('p1').set({
        'role': 'player',
        'name': 'Peer',
        'gender': 'male',
        'injured': true,
      });

      final peers =
          await repo.watchPeers(myUid: 'me', myGender: 'male').first;
      expect(peers.single.injured, isTrue);
    });
  });

  group('adjustMembership / markUnpaid', () {
    Future<DateTime> readPaidUntil(String uid) async {
      final doc = await db.collection('users').doc(uid).get();
      return (doc.data()!['paidUntil'] as Timestamp).toDate();
    }

    Future<void> setPaidUntil(String uid, DateTime until) =>
        db.collection('users').doc(uid).update(
            {'paidUntil': Timestamp.fromDate(until)});

    test('starts from today when the player has never paid', () async {
      await seedPlayer('p1', 'Player');

      await repo.adjustMembership('p1',
          days: 30, coachUid: 'c1', coachName: 'Coach');

      expect((await readPaidUntil('p1')).difference(DateTime.now()).inDays,
          inInclusiveRange(29, 30));
    });

    // The whole point of the feature: 10 days left + 20 added = 30, not 20.
    test('stacks onto the days a still-active member has left', () async {
      await seedPlayer('p1', 'Player');
      await setPaidUntil('p1', DateTime.now().add(const Duration(days: 10)));

      await repo.adjustMembership('p1',
          days: 20, coachUid: 'c1', coachName: 'Coach');

      expect((await readPaidUntil('p1')).difference(DateTime.now()).inDays,
          inInclusiveRange(29, 30));
    });

    test('restarts from today when the membership already lapsed', () async {
      await seedPlayer('p1', 'Player');
      await setPaidUntil('p1', DateTime.now().subtract(const Duration(days: 40)));

      await repo.adjustMembership('p1',
          days: 30, coachUid: 'c1', coachName: 'Coach');

      expect((await readPaidUntil('p1')).difference(DateTime.now()).inDays,
          inInclusiveRange(29, 30));
    });

    test('returns the new expiry and audits the days granted', () async {
      await seedPlayer('p1', 'Player');

      final until = await repo.adjustMembership('p1',
          days: 45, coachUid: 'c1', coachName: 'Coach');

      expect(until, await readPaidUntil('p1'));

      final audit =
          await db.collection('users').doc('p1').collection('payments').get();
      expect(audit.docs.length, 1);
      final entry = audit.docs.single.data();
      expect(entry['status'], 'paid');
      expect(entry['days'], 45);
      expect((entry['paidUntil'] as Timestamp).toDate(), until);
      expect(entry['changedBy'], 'c1');
    });

    test('takes days back off a still-active membership', () async {
      await seedPlayer('p1', 'Player');
      await setPaidUntil('p1', DateTime.now().add(const Duration(days: 30)));

      final until = await repo.adjustMembership('p1',
          days: -20, coachUid: 'c1', coachName: 'Coach');

      expect(until, isNotNull);
      expect((await readPaidUntil('p1')).difference(DateTime.now()).inDays,
          inInclusiveRange(9, 10));

      // Its own status, so the "last paid" lookup can't mistake a reduction
      // for a payment.
      final entry = (await db
              .collection('users')
              .doc('p1')
              .collection('payments')
              .get())
          .docs
          .single
          .data();
      expect(entry['status'], 'adjusted');
      expect(entry['days'], -20);
    });

    test('a reduction leaves the last-paid date alone', () async {
      await seedPlayer('p1', 'Player');
      await repo.adjustMembership('p1',
          days: 30, coachUid: 'c1', coachName: 'Coach');
      final paidAt =
          (await db.collection('users').doc('p1').get()).data()!['paidAt'];

      await repo.adjustMembership('p1',
          days: -5, coachUid: 'c1', coachName: 'Coach');

      expect((await db.collection('users').doc('p1').get()).data()!['paidAt'],
          paidAt);
    });

    test('taking back more days than are left ends the membership', () async {
      await seedPlayer('p1', 'Player');
      await setPaidUntil('p1', DateTime.now().add(const Duration(days: 10)));

      final until = await repo.adjustMembership('p1',
          days: -30, coachUid: 'c1', coachName: 'Coach');

      // Ended outright rather than left with a stale past expiry.
      expect(until, isNull);
      final doc = await db.collection('users').doc('p1').get();
      expect(doc.data()!.containsKey('paidUntil'), isFalse);
      expect(doc.data()!.containsKey('paidAt'), isFalse);

      final entry = (await db
              .collection('users')
              .doc('p1')
              .collection('payments')
              .get())
          .docs
          .single
          .data();
      expect(entry['status'], 'unpaid');
      expect(entry.containsKey('paidUntil'), isFalse);
    });

    test('markUnpaid clears payment fields and writes an audit entry',
        () async {
      await seedPlayer('p1', 'Player');
      await repo.adjustMembership('p1',
          days: 30, coachUid: 'c1', coachName: 'Coach');

      await repo.markUnpaid('p1', coachUid: 'c1', coachName: 'Coach');

      final doc = await db.collection('users').doc('p1').get();
      expect(doc.data()!.containsKey('paidUntil'), isFalse);
      expect(doc.data()!.containsKey('paidAt'), isFalse);

      final audit =
          await db.collection('users').doc('p1').collection('payments').get();
      expect(audit.docs.length, 2);
    });

    test('both are no-ops for lifetime members', () async {
      await seedPlayer('p1', 'Player', lifetime: true);

      final until = await repo.adjustMembership('p1',
          days: 30, coachUid: 'c1', coachName: 'Coach');
      await repo.markUnpaid('p1', coachUid: 'c1', coachName: 'Coach');

      expect(until, isNull);
      final doc = await db.collection('users').doc('p1').get();
      expect(doc.data()!.containsKey('paidUntil'), isFalse);
      final audit =
          await db.collection('users').doc('p1').collection('payments').get();
      expect(audit.docs, isEmpty);
    });
  });
}
