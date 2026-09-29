import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/firebase/firebase_providers.dart' show kCallableOptions;
import '../../domain/entities/coach_summary.dart';

class CoachesRemoteDataSource {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CoachesRemoteDataSource(this._db, this._functions);

  Stream<List<CoachSummary>> watchCoaches() => _db
          .collection('users_public')
          .where('role', isEqualTo: 'coach')
          .snapshots()
          .map((snap) {
        final coaches = snap.docs.map(CoachSummary.fromDoc).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return coaches;
      });

  /// Staff-only permanent account deletion. The callable enforces that the
  /// caller is a coach/admin server-side and refuses admin accounts and
  /// lifetime members (failed-precondition).
  Future<void> deleteCoach(String uid) =>
      _functions.httpsCallable('adminDeleteUser', options: kCallableOptions).call({'userId': uid});
}