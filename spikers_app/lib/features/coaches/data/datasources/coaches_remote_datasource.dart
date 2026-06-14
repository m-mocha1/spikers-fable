import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/coach_summary.dart';

class CoachesRemoteDataSource {
  final FirebaseFirestore _db;

  CoachesRemoteDataSource(this._db);

  Stream<List<CoachSummary>> watchCoaches() => _db
          .collection('users_public')
          .where('role', isEqualTo: 'coach')
          .snapshots()
          .map((snap) {
        final coaches = snap.docs.map(CoachSummary.fromDoc).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return coaches;
      });
}
// yh