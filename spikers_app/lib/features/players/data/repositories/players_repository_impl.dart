import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import '../../domain/entities/player_summary.dart';
import '../../domain/repositories/players_repository.dart';
import '../datasources/players_remote_datasource.dart';

class PlayersRepositoryImpl implements PlayersRepository {
  final PlayersRemoteDataSource _remote;

  PlayersRepositoryImpl(this._remote);

  @override
  Stream<List<PlayerSummary>> watchPlayers() => _remote.watchPlayers();

  @override
  Stream<List<PeerSummary>> watchPeers(
          {required String myUid, required String myGender}) =>
      _remote.watchPeers(myUid: myUid, myGender: myGender);

  @override
  Stream<UserModel?> watchPlayer(String uid) => _remote.watchPlayer(uid);

  @override
  Future<void> markPaid(String playerUid,
          {required String coachUid, required String coachName}) =>
      _remote.markPaid(playerUid, coachUid: coachUid, coachName: coachName);

  @override
  Future<void> markUnpaid(String playerUid,
          {required String coachUid, required String coachName}) =>
      _remote.markUnpaid(playerUid, coachUid: coachUid, coachName: coachName);

  @override
  Future<void> deletePlayer(String uid) => _remote.deletePlayer(uid);
}
