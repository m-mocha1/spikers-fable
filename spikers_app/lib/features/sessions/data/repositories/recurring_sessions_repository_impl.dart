import 'package:spikers_app/features/sessions/domain/entities/recurring_session_model.dart';
import '../../domain/repositories/recurring_sessions_repository.dart';
import '../datasources/sessions_remote_datasource.dart';

class RecurringSessionsRepositoryImpl implements RecurringSessionsRepository {
  final SessionsRemoteDataSource _remote;

  RecurringSessionsRepositoryImpl(this._remote);

  @override
  Stream<List<RecurringSessionModel>> watchForCoach(String coachUid) =>
      _remote.watchRecurringForCoach(coachUid);

  @override
  Future<void> create(RecurringSessionModel model) =>
      _remote.createRecurring(model);

  @override
  Future<void> edit(String id, Map<String, dynamic> data) =>
      _remote.editRecurring(id, data);

  @override
  Future<void> toggleEnabled(String id, bool enabled) =>
      _remote.editRecurring(id, {'enabled': enabled});

  @override
  Future<void> delete(String id) => _remote.deleteRecurring(id);
}
