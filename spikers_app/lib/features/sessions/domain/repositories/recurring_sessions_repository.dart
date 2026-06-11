import '../../../../models/recurring_session_model.dart';

abstract class RecurringSessionsRepository {
  /// The coach's recurring schedules, newest first. Malformed docs are
  /// skipped, not fatal.
  Stream<List<RecurringSessionModel>> watchForCoach(String coachUid);

  Future<void> create(RecurringSessionModel model);

  Future<void> edit(String id, Map<String, dynamic> data);

  Future<void> toggleEnabled(String id, bool enabled);

  Future<void> delete(String id);
}
