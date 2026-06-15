import '../entities/coach_summary.dart';

abstract class CoachesRepository {
  /// All coaches from the public mirror, name-sorted.
  Stream<List<CoachSummary>> watchCoaches();

  /// Admin-only: permanently deletes the coach's account (Auth + Firestore
  /// + photo) via the adminDeleteUser callable. Authorization is enforced
  /// server-side.
  Future<void> deleteCoach(String uid);
}
