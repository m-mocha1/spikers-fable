import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class LeaderboardEntry {
  final String uid;
  final String name;
  final String photoUrl;
  final int count;

  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.count,
  });
}

class LeaderboardController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final allTimeEntries = <LeaderboardEntry>[].obs;
  final monthlyEntries = <LeaderboardEntry>[].obs;
  final isLoadingAllTime = true.obs;
  final isLoadingMonthly = true.obs;
  final selectedTab = 0.obs;

  @override
  void onInit() {
    super.onInit();
    Future.wait([_fetchAllTime(), _fetchMonthly()]);
  }

  Future<void> reload() async {
    isLoadingAllTime.value = true;
    isLoadingMonthly.value = true;
    await Future.wait([_fetchAllTime(), _fetchMonthly()]);
  }

  Future<void> _fetchAllTime() async {
    try {
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
          count: count,
        ));
      }
      entries.sort((a, b) => b.count.compareTo(a.count));
      allTimeEntries.value = entries;
    } catch (e) {
      debugPrint('LeaderboardController: all-time fetch failed — $e');
    } finally {
      isLoadingAllTime.value = false;
    }
  }

  Future<void> _fetchMonthly() async {
    try {
      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month);
      final cutoff = Timestamp.fromDate(firstOfMonth);

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
          final attendedIds =
              List<String>.from(doc.data()['attendedIds'] ?? []);
          for (final uid in attendedIds) {
            counts[uid] = (counts[uid] ?? 0) + 1;
          }
        }
      }

      if (counts.isEmpty) {
        monthlyEntries.value = [];
        return;
      }

      final uids = counts.keys.toList();
      final profiles = <String, Map<String, dynamic>>{};
      for (var i = 0; i < uids.length; i += 10) {
        final batch = uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10);
        final snap = await _db
            .collection('users_public')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final doc in snap.docs) {
          profiles[doc.id] = doc.data();
        }
      }

      final entries = <LeaderboardEntry>[];
      for (final uid in uids) {
        final data = profiles[uid];
        entries.add(LeaderboardEntry(
          uid: uid,
          name: (data?['name'] ?? '') as String,
          photoUrl: (data?['photoUrl'] ?? '') as String,
          count: counts[uid] ?? 0,
        ));
      }
      entries.sort((a, b) => b.count.compareTo(a.count));
      monthlyEntries.value = entries;
    } catch (e) {
      debugPrint('LeaderboardController: monthly fetch failed — $e');
    } finally {
      isLoadingMonthly.value = false;
    }
  }
}
