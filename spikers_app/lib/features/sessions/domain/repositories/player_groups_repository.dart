import 'package:spikers_app/features/sessions/domain/entities/player_group_model.dart';

abstract class PlayerGroupsRepository {
  /// All shared player groups, most-recently-updated first.
  Stream<List<PlayerGroup>> watch();

  /// Creates the group when [group].id is empty, otherwise updates it
  /// (rename and/or new member list). New groups carry [group].createdBy.
  Future<void> save(PlayerGroup group);

  Future<void> delete(String groupId);
}
