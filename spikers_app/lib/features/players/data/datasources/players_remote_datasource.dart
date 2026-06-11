import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import '../../domain/entities/player_summary.dart';

class PlayersRemoteDataSource {
  final FirebaseFirestore _db;

  PlayersRemoteDataSource(this._db);

  static const _paymentPeriodDays = 30;

  // Roster queries stay unlimited on purpose: the club roster is small and
  // a server-side limit would need an orderBy + composite index we can't
  // deploy from this experimental copy. Revisit before real growth.
  Stream<List<PlayerSummary>> watchPlayers() => _db
          .collection('users')
          .where('role', isEqualTo: 'player')
          .snapshots()
          .map((snap) {
        final players = snap.docs.map(PlayerSummary.fromDoc).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return players;
      });

  Stream<List<PeerSummary>> watchPeers(
          {required String myUid, required String myGender}) =>
      _db
          .collection('users_public')
          .where('role', isEqualTo: 'player')
          .where('gender', isEqualTo: myGender)
          .snapshots()
          .map((snap) {
        final peers = snap.docs
            .where((d) => d.id != myUid)
            .map(PeerSummary.fromDoc)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return peers;
      });

  Stream<UserModel?> watchPlayer(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? UserModel.fromDoc(doc) : null);

  Future<bool> isLifetimeMember(String playerUid) async {
    final snap = await _db.collection('users').doc(playerUid).get();
    return (snap.data()?['lifetimeMember'] ?? false) as bool;
  }

  Future<void> markPaid(String playerUid,
      {required String coachUid, required String coachName}) async {
    if (await isLifetimeMember(playerUid)) return;

    final now = DateTime.now();
    final until = now.add(const Duration(days: _paymentPeriodDays));
    final userRef = _db.collection('users').doc(playerUid);
    final auditRef = userRef.collection('payments').doc();

    final batch = _db.batch();
    batch.update(userRef, {
      'paidUntil': Timestamp.fromDate(until),
      'paidAt': Timestamp.fromDate(now),
    });
    batch.set(auditRef, {
      'status': 'paid',
      'changedAt': Timestamp.fromDate(now),
      'changedBy': coachUid,
      'changedByName': coachName,
    });
    await batch.commit();
  }

  Future<void> markUnpaid(String playerUid,
      {required String coachUid, required String coachName}) async {
    if (await isLifetimeMember(playerUid)) return;

    final now = DateTime.now();
    final userRef = _db.collection('users').doc(playerUid);
    final auditRef = userRef.collection('payments').doc();

    final batch = _db.batch();
    batch.update(userRef, {
      'paidUntil': FieldValue.delete(),
      'paidAt': FieldValue.delete(),
    });
    batch.set(auditRef, {
      'status': 'unpaid',
      'changedAt': Timestamp.fromDate(now),
      'changedBy': coachUid,
      'changedByName': coachName,
    });
    await batch.commit();
  }
}
