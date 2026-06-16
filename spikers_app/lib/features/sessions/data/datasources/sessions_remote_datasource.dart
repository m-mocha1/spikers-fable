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
        final data = doc.data();
        profiles[doc.id] = (
          name: (data['name'] ?? '') as String,
          photoUrl: (data['photoUrl'] ?? '') as String,
          gender: (data['gender'] ?? '') as String,
          attendanceCount: ((data['attendanceCount'] ?? 0) as num).toInt(),
        );
      }
    }
    return profiles;
  }

  Future<void> create(SessionModel session) async {
    final payload = session.toMap();
    payload['designIndex'] = _random.nextInt(AppAssets.cardDesigns.length);
    await _db.collection('sessions').add(payload);
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
