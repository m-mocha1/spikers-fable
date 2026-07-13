import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/leaderboard_entry.dart';

class LeaderboardRemoteDataSource {
  final FirebaseFirestore _db;

  LeaderboardRemoteDataSource(this._db);

  Future<List<LeaderboardEntry>> fetchAllTime() async {
    // Top players by attendance. orderBy+limit keeps this bounded as the
    // roster grows (docs missing attendanceCount are excluded, which is fine
    // since we skip non-positive counts anyway).
    final snap = await _db
        .collection('users_public')
        .orderBy('attendanceCount', descending: true)
        .limit(200)
        .get();
    final entries = <LeaderboardEntry>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final count = ((data['attendanceCount'] ?? 0) as num).toInt();
      if (count <= 0) continue;
      entries.add(LeaderboardEntry(
        uid: doc.id,
        name: (data['name'] ?? '') as String,
        photoUrl: (data['photoUrl'] ?? '') as String,
        gender: (data['gender'] ?? '') as String,
        count: count,
      ));
    }
    entries.sort((a, b) => b.count.compareTo(a.count));
    return entries;
  }

  Future<List<LeaderboardEntry>> fetchEndorsements() async {
    // Top players by lifetime endorsements received. Only the aggregate
    // endorsementCount is public (users_public, maintained server-side by
    // endorsePlayer + mirrorUserPublic) — individual endorsement docs are
    // private, which is also why this board has no monthly slice.
    final snap = await _db
        .collection('users_public')
        .orderBy('endorsementCount', descending: true)
        .limit(200)
        .get();
    final entries = <LeaderboardEntry>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final count = ((data['endorsementCount'] ?? 0) as num).toInt();
      if (count <= 0) continue;
      entries.add(LeaderboardEntry(
        uid: doc.id,
        name: (data['name'] ?? '') as String,
        photoUrl: (data['photoUrl'] ?? '') as String,
        gender: (data['gender'] ?? '') as String,
        count: count,
      ));
    }
    entries.sort((a, b) => b.count.compareTo(a.count));
    return entries;
  }

  Future<List<LeaderboardEntry>> fetchMonthly() async {
    final now = DateTime.now();
    final cutoff = Timestamp.fromDate(DateTime(now.year, now.month));

    final results = await Future.wait([
      _db
          .collection('sessions_history')
          .where('startTime', isGreaterThanOrEqualTo: cutoff)
          .get(),
      _db
          .collection('sessions')
          .where('startTime', isGreaterThanOrEqualTo: cutoff)
          .get(),
    ]);

    final counts = <String, int>{};
    for (final snap in results) {
      for (final doc in snap.docs) {
        final attendedIds = List<String>.from(doc.data()['attendedIds'] ?? []);
        for (final uid in attendedIds) {
          counts[uid] = (counts[uid] ?? 0) + 1;
        }
      }
    }
    if (counts.isEmpty) return const [];

    final uids = counts.keys.toList();
    // whereIn caps at 30 ids per query; fetch all chunks in parallel so a
    // busy month costs one round trip, not one per chunk.
    final snaps = await Future.wait([
      for (var i = 0; i < uids.length; i += 30)
        _db
            .collection('users_public')
            .where(FieldPath.documentId,
                whereIn: uids.sublist(i, min(i + 30, uids.length)))
            .get(),
    ]);
    final profiles = <String, Map<String, dynamic>>{
      for (final snap in snaps)
        for (final doc in snap.docs) doc.id: doc.data(),
    };

    final entries = <LeaderboardEntry>[
      for (final uid in uids)
        LeaderboardEntry(
          uid: uid,
          name: (profiles[uid]?['name'] ?? '') as String,
          photoUrl: (profiles[uid]?['photoUrl'] ?? '') as String,
          gender: (profiles[uid]?['gender'] ?? '') as String,
          count: counts[uid] ?? 0,
        ),
    ];
    entries.sort((a, b) => b.count.compareTo(a.count));
    return entries;
  }
}
