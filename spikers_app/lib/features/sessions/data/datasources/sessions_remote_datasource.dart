import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_assets.dart';
import 'package:spikers_app/features/sessions/domain/entities/chat_message_model.dart';
import 'package:spikers_app/features/sessions/domain/entities/recurring_session_model.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_template_model.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import '../../domain/repositories/sessions_repository.dart'
    show PublicProfile;

class SessionsRemoteDataSource {
  final FirebaseFirestore _db;
  final FirebaseFunctions _fns;
  final _random = Random();

  SessionsRemoteDataSource(this._db, this._fns);

  // --- sessions list / detail -------------------------------------------

  Stream<List<SessionModel>> watchUpcoming(UserModel viewer) {
    Query<Map<String, dynamic>> query = _db
        .collection('sessions')
        .where('endTime', isGreaterThan: Timestamp.fromDate(DateTime.now()));

    // Gender/age are optional on the profile. When a player hasn't provided
    // them we skip that filter dimension and show the broader set rather than
    // matching on a value we don't have.
    if (!viewer.isCoach && viewer.gender != null) {
      query = query.where('gender', whereIn: [viewer.gender, 'mixed']);
    }
    query = query.orderBy('endTime').orderBy('startTime');

    return query.snapshots().map((snapshot) {
      final now = DateTime.now();
      var all = snapshot.docs
          .map(SessionModel.fromDoc)
          .where((s) => s.endTime.isAfter(now))
          .toList();
      if (!viewer.isCoach) {
        final age = viewer.age;
        if (age != null) {
          all = all.where((s) => age >= s.minAge && age <= s.maxAge).toList();
        }
      }
      all.sort((a, b) => a.startTime.compareTo(b.startTime));
      return all;
    });
  }

  Stream<SessionModel?> watchSession(String id) => _db
      .collection('sessions')
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? SessionModel.fromDoc(doc) : null);

  Stream<SessionModel?> watchArchivedSession(String id) => _db
      .collection('sessions_history')
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? SessionModel.fromDoc(doc) : null);

  Stream<List<SessionModel>> watchHistory({required int limit}) => _db
      .collection('sessions_history')
      .orderBy('endTime', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) => snap.docs.map(SessionModel.fromDoc).toList());

  Future<Map<String, PublicProfile>> fetchPublicProfiles(
      List<String> uids) async {
    final profiles = <String, PublicProfile>{};
    for (var i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(i, (i + 30).clamp(0, uids.length));
      final snap = await _db
          .collection('users_public')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        profiles[doc.id] = _profileFromData(doc.data());
      }
    }
    return profiles;
  }

  /// Live single-profile view of users_public/{uid}; null while the mirror doc
  /// doesn't exist yet. Lets the owner's profile stats (games played,
  /// endorsements) update the instant a coach marks attendance or an
  /// endorsement lands, instead of only on a reload.
  Stream<PublicProfile?> watchPublicProfile(String uid) => _db
      .collection('users_public')
      .doc(uid)
      .snapshots()
      .map((doc) {
        final data = doc.data();
        return data == null ? null : _profileFromData(data);
      });

  PublicProfile _profileFromData(Map<String, dynamic> data) => (
        name: (data['name'] ?? '') as String,
        photoUrl: (data['photoUrl'] ?? '') as String,
        gender: (data['gender'] ?? '') as String,
        attendanceCount: ((data['attendanceCount'] ?? 0) as num).toInt(),
        injured: (data['injured'] ?? false) as bool,
        endorsementCount: ((data['endorsementCount'] ?? 0) as num).toInt(),
      );

  /// Start times of sessions where [uid] was marked attended — archived
  /// history plus any not-yet-archived live sessions. Newest-first, bounded by
  /// [limit] so a long-standing member doesn't pull their entire history
  /// (the streak computation only needs recent weeks; ~100 docs covers 30+
  /// weeks even at 3 sessions/week).
  ///
  /// The history query (array-contains + orderBy) is backed by the composite
  /// index on (attendedIds, startTime) in firestore.indexes.json.
  Future<List<DateTime>> fetchAttendedTimes(String uid,
      {int limit = 100}) async {
    final results = await Future.wait([
      _db
          .collection('sessions_history')
          .where('attendedIds', arrayContains: uid)
          .orderBy('startTime', descending: true)
          .limit(limit)
          .get(),
      // Live collection is small (upcoming + today's sessions), so a plain
      // array-contains needs no ordering or composite index.
      _db.collection('sessions').where('attendedIds', arrayContains: uid).get(),
    ]);
    return [
      for (final snap in results)
        for (final doc in snap.docs)
          (doc.data()['startTime'] as Timestamp).toDate(),
    ];
  }

  Future<void> create(SessionModel session) async {
    final previous = await _mostRecentDesignIndex();
    final payload = session.toMap();
    payload['designIndex'] = _pickDesignIndex(previous);
    await _db.collection('sessions').add(payload);
  }

  /// The card-design index of the most recently created session, normalized to
  /// the current [AppAssets.cardDesigns] length. Returns null when there is no
  /// prior session (or its value is missing/non-numeric).
  Future<int?> _mostRecentDesignIndex() async {
    final snap = await _db
        .collection('sessions')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final raw = snap.docs.first.data()['designIndex'];
    if (raw is! num) return null;
    return raw.toInt() % AppAssets.cardDesigns.length;
  }

  /// Picks a random card-design index, avoiding [previous] so two consecutive
  /// sessions don't share the same card. Falls back to a plain uniform draw when
  /// there's no previous index or only one design to choose from.
  int _pickDesignIndex(int? previous) {
    final count = AppAssets.cardDesigns.length;
    if (count <= 1 || previous == null || previous < 0 || previous >= count) {
      return _random.nextInt(count);
    }
    // Draw from the (count - 1) other slots, then shift past the excluded one.
    final draw = _random.nextInt(count - 1);
    return draw < previous ? draw : draw + 1;
  }

  // --- callable functions -------------------------------------------------

  Future<String> join(String sessionId) async {
    final res =
        await _fns.httpsCallable('joinSession').call({'sessionId': sessionId});
    return (res.data?['status'] as String?) ?? '';
  }

  Future<void> leave(String sessionId) =>
      _fns.httpsCallable('leaveSession').call({'sessionId': sessionId});

  Future<void> cancel(String sessionId) =>
      _fns.httpsCallable('cancelSession').call({'sessionId': sessionId});

  Future<void> updateCapacity(String sessionId,
          {int? newMaxPlayers, int? newWaitlistSize}) =>
      _fns.httpsCallable('updateSessionCapacity').call({
        'sessionId': sessionId,
        'newMaxPlayers': ?newMaxPlayers,
        'newWaitlistSize': ?newWaitlistSize,
      });

  Future<void> markAttended(String sessionId, String userId, bool attended) =>
      _fns.httpsCallable('markAttended').call({
        'sessionId': sessionId,
        'userId': userId,
        'attended': attended,
      });

  Future<void> removeAttendee(String sessionId, String userId) =>
      _fns.httpsCallable('removeAttendee').call({
        'sessionId': sessionId,
        'userId': userId,
      });

  Future<void> endorse(String sessionId, String userId) =>
      _fns.httpsCallable('endorsePlayer').call({
        'sessionId': sessionId,
        'userId': userId,
      });

  /// The signed-in user's OWN outgoing endorsements (fromUid == [myUid]) is the
  /// only query shape the security rules permit; sessionId is filtered
  /// client-side to avoid needing a composite index. Emits the set of target
  /// uids already endorsed in [sessionId].
  Stream<Set<String>> watchMyEndorsements(String sessionId, String myUid) => _db
      .collection('endorsements')
      .where('fromUid', isEqualTo: myUid)
      .snapshots()
      .map((snap) => snap.docs
          .where((d) => d.data()['sessionId'] == sessionId)
          .map((d) => d.data()['toUid'] as String)
          .toSet());

  Future<void> archiveExpiredNow() async {
    try {
      await _fns.httpsCallable('archiveExpiredSessionsNow').call();
    } catch (e) {
      // Non-fatal: the scheduled sessionCleanup function archives it anyway.
      debugPrint('sessions: on-demand archival failed — $e');
    }
  }

  // --- chat ----------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _messages(String sessionId) =>
      _db.collection('sessions').doc(sessionId).collection('messages');

  Stream<List<ChatMessage>> watchLatestMessages(String sessionId,
          {required int limit}) =>
      _messages(sessionId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());

  Future<List<ChatMessage>> fetchOlderMessages(String sessionId,
      {required DateTime before, required int limit}) async {
    final snap = await _messages(sessionId)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();
    return snap.docs.map(ChatMessage.fromDoc).toList();
  }

  Future<void> sendMessage(String sessionId,
          {required String senderId, required String text}) =>
      _messages(sessionId).add({
        'senderId': senderId,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

  // --- templates -------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _templates(String uid) =>
      _db.collection('users').doc(uid).collection('templates');

  Stream<List<SessionTemplate>> watchTemplates(String coachUid) =>
      _templates(coachUid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(SessionTemplate.fromDoc).toList());

  Future<void> saveTemplate(String coachUid, SessionTemplate template) =>
      _templates(coachUid).add(template.toMap());

  Future<void> deleteTemplate(String coachUid, String templateId) =>
      _templates(coachUid).doc(templateId).delete();

  // --- recurring sessions ----------------------------------------------

  Stream<List<RecurringSessionModel>> watchRecurringForCoach(
          String coachUid) =>
      _db
          .collection('recurring_sessions')
          .where('coachId', isEqualTo: coachUid)
          .snapshots()
          .map((snap) {
        final list = <RecurringSessionModel>[];
        for (final d in snap.docs) {
          try {
            list.add(RecurringSessionModel.fromDoc(d));
          } catch (e) {
            debugPrint('recurring_sessions: skip ${d.id} — $e');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  Future<void> createRecurring(RecurringSessionModel model) =>
      _db.collection('recurring_sessions').add(model.toMap());

  Future<void> editRecurring(String id, Map<String, dynamic> data) =>
      _db.collection('recurring_sessions').doc(id).update(data);

  Future<void> deleteRecurring(String id) =>
      _db.collection('recurring_sessions').doc(id).delete();
}
