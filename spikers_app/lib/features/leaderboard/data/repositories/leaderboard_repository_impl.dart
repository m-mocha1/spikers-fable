import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_remote_datasource.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final LeaderboardRemoteDataSource _remote;

  LeaderboardRepositoryImpl(this._remote);

  @override
  Future<List<LeaderboardEntry>> fetchAllTime() => _remote.fetchAllTime();

  @override
  Future<List<LeaderboardEntry>> fetchMonthly() => _remote.fetchMonthly();
}
