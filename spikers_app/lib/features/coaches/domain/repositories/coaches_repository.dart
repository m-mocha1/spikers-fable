import '../entities/coach_summary.dart';

abstract class CoachesRepository {
  /// All coaches from the public mirror, name-sorted.
  Stream<List<CoachSummary>> watchCoaches();
}
