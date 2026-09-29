import 'package:cloud_firestore/cloud_firestore.dart' show GetOptions;
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';

import '../../../../core/firebase/cache_first.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_remote_datasource.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final LeaderboardRemoteDataSource _remote;

  LeaderboardRepositoryImpl(this._remote);

  // Same visibility rule as the sessions lists: players only compete within
  // their own gender; coaches/admins see everyone. A missing viewer gender
  // skips the filter rather than matching on a value we don't have.
  List<LeaderboardEntry> _visibleTo(
          UserModel viewer, List<LeaderboardEntry> entries) =>
      viewer.isCoach || viewer.gender == null
          ? entries
          : entries.where((e) => e.gender == viewer.gender).toList();

  @override
  Future<List<LeaderboardEntry>> fetchAllTime(UserModel viewer) async =>
      _visibleTo(viewer, await _remote.fetchAllTime());

  @override
  Future<List<LeaderboardEntry>> fetchMonthly(UserModel viewer) async =>
      _visibleTo(viewer, await _remote.fetchMonthly());

  @override
  Future<List<LeaderboardEntry>> fetchEndorsements(UserModel viewer) async =>
      _visibleTo(viewer, await _remote.fetchEndorsements());

  @override
  Stream<List<LeaderboardEntry>> watchAllTime(UserModel viewer) =>
      _cacheFirst(viewer, _remote.fetchAllTime);

  @override
  Stream<List<LeaderboardEntry>> watchMonthly(UserModel viewer) =>
      _cacheFirst(viewer, _remote.fetchMonthly);

  @override
  Stream<List<LeaderboardEntry>> watchEndorsements(UserModel viewer) =>
      _cacheFirst(viewer, _remote.fetchEndorsements);

  Stream<List<LeaderboardEntry>> _cacheFirst(
    UserModel viewer,
    Future<List<LeaderboardEntry>> Function(GetOptions options) fetch,
  ) =>
      cacheThenServer(fetch, isUsable: (entries) => entries.isNotEmpty)
          .map((entries) => _visibleTo(viewer, entries));
}
