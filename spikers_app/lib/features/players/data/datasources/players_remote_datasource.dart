import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import '../../domain/entities/player_summary.dart';

class PlayersRemoteDataSource {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  PlayersRemoteDataSource(this._db, this._functions, this._storage);

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
      {required String myUid, String? myGender}) {
    // Gender is optional on the profile. Without it we can't show same-gender
    // peers, so we fall back to showing all players.
    Query<Map<String, dynamic>> q = _db
        .collection('users_public')
        .where('role', isEqualTo: 'player');
    if (myGender != null) {
      q = q.where('gender', isEqualTo: myGender);
    }
    return q.snapshots().map((snap) {
      final peers = snap.docs
          .where((d) => d.id != myUid)
          .map(PeerSummary.fromDoc)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return peers;
    });
  }

  Stream<UserModel?> watchPlayer(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? UserModel.fromDoc(doc) : null);

  Future<bool> isLifetimeMember(String playerUid) async {
    final snap = await _db.collection('users').doc(playerUid).get();
    return (snap.data()?['lifetimeMember'] ?? false) as bool;
  }

  /// Moves the player's membership expiry by [days] — positive to add time,
  /// negative to take it back. Time stacks on top of whatever is left: a
  /// player with 10 days remaining who is given 20 ends up with 30, not 20,
  /// and taking 5 back leaves 5. Expired and never-paid players start from now.
  ///
  /// Taking away at least as many days as were left ends the membership
  /// outright — the fields are cleared exactly as [markUnpaid] does, rather
  /// than leaving a stale past expiry on the document.
  ///
  /// Runs in a transaction so the lifetime check, the current-expiry read and
  /// the write are atomic — two coaches adjusting at once both apply their
  /// change instead of one silently overwriting the other. The current expiry
  /// is read from Firestore rather than taken from the caller for the same
  /// reason.
  ///
  /// Returns the new expiry, or null when the player has no active membership
  /// afterwards: a lifetime member (a no-op, their membership never lapses) or
  /// a reduction that consumed everything that was left.
  Future<DateTime?> adjustMembership(
    String playerUid, {
    required int days,
    required String coachUid,
    required String coachName,
  }) async {
    final now = DateTime.now();
    final userRef = _db.collection('users').doc(playerUid);
    final auditRef = userRef.collection('payments').doc();

    return _db.runTransaction<DateTime?>((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data();
      if ((data?['lifetimeMember'] ?? false) as bool) return null;

      final paidUntil = (data?['paidUntil'] as Timestamp?)?.toDate();
      final base =
          (paidUntil != null && paidUntil.isAfter(now)) ? paidUntil : now;
      final until = base.add(Duration(days: days));
      final ended = !until.isAfter(now);

      tx.update(
        userRef,
        ended
            ? {
                'paidUntil': FieldValue.delete(),
                'paidAt': FieldValue.delete(),
              }
            : {
                'paidUntil': Timestamp.fromDate(until),
                // Only a renewal is a payment; a reduction leaves the record of
                // when the player last actually paid alone.
                if (days > 0) 'paidAt': Timestamp.fromDate(now),
              },
      );
      // `days` (signed) and `paidUntil` let the history screen show what was
      // actually granted or taken back; older records predate both fields and
      // render without that line. Reductions use their own status so they
      // don't count as payments in the "last paid" lookup.
      tx.set(auditRef, {
        'status': ended
            ? 'unpaid'
            : days < 0
                ? 'adjusted'
                : 'paid',
        'days': days,
        if (!ended) 'paidUntil': Timestamp.fromDate(until),
        'changedAt': Timestamp.fromDate(now),
        'changedBy': coachUid,
        'changedByName': coachName,
      });
      return ended ? null : until;
    });
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

  /// Admin-only permanent account deletion. The callable enforces that the
  /// caller is an admin server-side.
  Future<void> deletePlayer(String uid) =>
      _functions.httpsCallable('adminDeleteUser').call({'userId': uid});

  /// Coach/admin uploads a new profile photo for [uid] and points that user's
  /// photoUrl at it. Same storage path and downscaled image as the self-flow
  /// (`AuthRemoteDataSource.uploadProfilePhoto`). Authorization is enforced by
  /// storage.rules (coach may upload) and firestore.rules (photoUrl may only
  /// be set on a player target).
  Future<void> updatePlayerPhoto(String uid, String filePath) async {
    final ref = _storage.ref('profilePhotos/$uid.jpg');
    await ref.putFile(File(filePath));
    final url = await ref.getDownloadURL();
    await _db.collection('users').doc(uid).update({'photoUrl': url});
  }

  /// Coach/admin renames another player. The callable enforces server-side
  /// that the caller is staff and that the target is a plain player (staff
  /// accounts can't be renamed by others).
  Future<void> renamePlayer(String uid, String name) => _functions
      .httpsCallable('coachRenamePlayer')
      .call({'userId': uid, 'name': name.trim()});
}
