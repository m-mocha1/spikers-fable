import 'package:spikers_app/features/sessions/domain/entities/player_group_model.dart';
import '../../domain/repositories/player_groups_repository.dart';
import '../datasources/sessions_remote_datasource.dart';

class PlayerGroupsRepositoryImpl implements PlayerGroupsRepository {
  final SessionsRemoteDataSource _remote;

  PlayerGroupsRepositoryImpl(this._remote);

  @override
  Stream<List<PlayerGroup>> watch() => _remote.watchPlayerGroups();

  @override
  Future<void> save(PlayerGroup group) => _remote.savePlayerGroup(group);

  @override
  Future<void> delete(String groupId) => _remote.deletePlayerGroup(groupId);
}
