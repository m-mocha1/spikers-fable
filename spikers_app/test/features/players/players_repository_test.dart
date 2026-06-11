import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/features/players/data/datasources/players_remote_datasource.dart';
import 'package:spikers_app/features/players/data/repositories/players_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PlayersRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = PlayersRepositoryImpl(PlayersRemoteDataSource(db));
  });

  Future<void> seedPlayer(String uid, String name,
      {String gender = 'male', bool lifetime = false}) async {
    await db.collection('users').doc(uid).set({
      'role': 'player',
      'name': name,
      'gender': gender,
      'lifetimeMember': lifetime,
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
