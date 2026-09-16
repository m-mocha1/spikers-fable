import 'package:cloud_functions/cloud_functions.dart';
import 'package:spikers_app/core/errors/account_action_exception.dart';
import '../../domain/entities/coach_summary.dart';
import '../../domain/repositories/coaches_repository.dart';
import '../datasources/coaches_remote_datasource.dart';

class CoachesRepositoryImpl implements CoachesRepository {
  final CoachesRemoteDataSource _remote;

  CoachesRepositoryImpl(this._remote);

  @override
  Stream<List<CoachSummary>> watchCoaches() => _remote.watchCoaches();

  @override
  Future<void> deleteCoach(String uid) async {
    try {
      await _remote.deleteCoach(uid);
    } on FirebaseFunctionsException catch (e) {
      throw AccountActionException(e.code);
    }
  }
}
