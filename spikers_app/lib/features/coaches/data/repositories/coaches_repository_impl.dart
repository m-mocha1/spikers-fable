import '../../domain/entities/coach_summary.dart';
import '../../domain/repositories/coaches_repository.dart';
import '../datasources/coaches_remote_datasource.dart';

class CoachesRepositoryImpl implements CoachesRepository {
  final CoachesRemoteDataSource _remote;

  CoachesRepositoryImpl(this._remote);

  @override
  Stream<List<CoachSummary>> watchCoaches() => _remote.watchCoaches();

  @override
  Future<void> deleteCoach(String uid) => _remote.deleteCoach(uid);
}
