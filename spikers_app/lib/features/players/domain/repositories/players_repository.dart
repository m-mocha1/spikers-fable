import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import '../entities/player_summary.dart';

abstract class PlayersRepository {
  /// All players with payment data, name-sorted (coach roster view).
  Stream<List<PlayerSummary>> watchPlayers();

  /// Same-gender peers from the public mirror, excluding the viewer.
  Stream<List<PeerSummary>> watchPeers(
      {required String myUid, required String myGender});

  /// Live user document for the profile screen; null when missing.
  Stream<UserModel?> watchPlayer(String uid);

  /// Marks 30 days paid from now, with an audit-trail entry. No-op for
  /// lifetime members.
  Future<void> markPaid(String playerUid,
      {required String coachUid, required String coachName});

  /// Clears payment fields, with an audit-trail entry. No-op for lifetime
  /// members.
  Future<void> markUnpaid(String playerUid,
      {required String coachUid, required String coachName});

  /// Admin-only: permanently deletes the player's account (Auth + Firestore
  /// + photo) via the adminDeleteUser callable. Authorization is enforced
  /// server-side.
  Future<void> deletePlayer(String uid);
}
