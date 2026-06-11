import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/features/leaderboard/data/datasources/leaderboard_remote_datasource.dart';
import 'package:spikers_app/features/leaderboard/data/repositories/leaderboard_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore db;
  late LeaderboardRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = LeaderboardRepositoryImpl(LeaderboardRemoteDataSource(db));
  });

  group('fetchAllTime', () {
    test('orders by attendance and skips non-positive counts', () async {
      await db.collection('users_public').doc('a').set({
        'name': 'Aya',
        'photoUrl': '',
        'attendanceCount': 3,
      });
      await db.collection('users_public').doc('b').set({
        'name': 'Badr',
        'photoUrl': 'http://x/p.jpg',
        'attendanceCount': 7,
      });
      await db.collection('users_public').doc('c').set({
        'name': 'Zero',
        'photoUrl': '',
        'attendanceCount': 0,
      });

      final entries = await repo.fetchAllTime();

      expect(entries.map((e) => e.uid), ['b', 'a']);
      expect(entries.first.count, 7);
      expect(entries.first.photoUrl, 'http://x/p.jpg');
    });

    test('returns empty when nobody has attendance', () async {
      await db
          .collection('users_public')
          .doc('a')
          .set({'name': 'Aya', 'attendanceCount': 0});
      expect(await repo.fetchAllTime(), isEmpty);
    });
  });

  group('fetchMonthly', () {
    test('merges live and archived sessions and joins profiles', () async {
      final thisMonth = Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 1)));
      final lastMonth = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 60)));

      await db.collection('sessions').doc('s1').set({
        'startTime': thisMonth,
        'attendedIds': ['u1', 'u2'],
      });
      await db.collection('sessions_history').doc('s2').set({
        'startTime': thisMonth,
        'attendedIds': ['u1'],
      });
      // Outside the window — must not count.
      await db.collection('sessions_history').doc('s3').set({
        'startTime': lastMonth,
        'attendedIds': ['u1', 'u2'],
      });

      await db.collection('users_public').doc('u1').set({
        'name': 'One',
        'photoUrl': '',
      });
      // u2 has no users_public doc — entry still appears with empty name.

      final entries = await repo.fetchMonthly();

      expect(entries.length, 2);
      expect(entries[0].uid, 'u1');
      expect(entries[0].count, 2);
      expect(entries[0].name, 'One');
      expect(entries[1].uid, 'u2');
      expect(entries[1].count, 1);
      expect(entries[1].name, '');
    });

    test('returns empty when no one attended this month', () async {
      expect(await repo.fetchMonthly(), isEmpty);
    });

    test('joins profiles for more than 10 uids (whereIn batching)', () async {
      final thisMonth =
          Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 1)));
      final uids = List.generate(13, (i) => 'u$i');
      await db.collection('sessions').doc('s1').set({
        'startTime': thisMonth,
        'attendedIds': uids,
      });
      for (final uid in uids) {
        await db
            .collection('users_public')
            .doc(uid)
            .set({'name': 'name-$uid', 'photoUrl': ''});
      }

      final entries = await repo.fetchMonthly();
      expect(entries.length, 13);
      expect(entries.every((e) => e.name == 'name-${e.uid}'), isTrue);
    });
  });
}
