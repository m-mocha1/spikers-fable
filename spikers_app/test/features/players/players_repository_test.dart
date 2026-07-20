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

  group('markPaid / markUnpaid', () {
    test('markPaid sets paidUntil ~30 days out and writes an audit entry',
        () async {
      await seedPlayer('p1', 'Player');

      await repo.markPaid('p1', coachUid: 'c1', coachName: 'Coach');

      final doc = await db.collection('users').doc('p1').get();
      final paidUntil = (doc.data()!['paidUntil'] as Timestamp).toDate();
      expect(
          paidUntil.difference(DateTime.now()).inDays, inInclusiveRange(29, 30));

      final audit =
          await db.collection('users').doc('p1').collection('payments').get();
      expect(audit.docs.length, 1);
      expect(audit.docs.single.data()['status'], 'paid');
      expect(audit.docs.single.data()['changedBy'], 'c1');
    });

    test('markUnpaid clears payment fields and writes an audit entry',
        () async {
      await seedPlayer('p1', 'Player');
      await repo.markPaid('p1', coachUid: 'c1', coachName: 'Coach');

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

      await repo.markPaid('p1', coachUid: 'c1', coachName: 'Coach');
      await repo.markUnpaid('p1', coachUid: 'c1', coachName: 'Coach');

      final doc = await db.collection('users').doc('p1').get();
      expect(doc.data()!.containsKey('paidUntil'), isFalse);
      final audit =
          await db.collection('users').doc('p1').collection('payments').get();
      expect(audit.docs, isEmpty);
    });
  });
}
