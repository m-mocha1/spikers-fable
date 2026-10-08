import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show GetOptions, Source;
import 'package:cloud_functions/cloud_functions.dart';

import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import '../../../../core/firebase/cache_first.dart';
import '../../domain/lineup.dart';
import '../../domain/repositories/sessions_repository.dart';
import '../datasources/sessions_remote_datasource.dart';

class SessionsRepositoryImpl implements SessionsRepository {
  final SessionsRemoteDataSource _remote;

  /// In-memory users_public cache (uid → profile), fed by every profile read.
  /// Lets screens seed attendee lists synchronously instead of blanking for a
  /// network round trip. Deliberately unbounded and never invalidated: the
  /// club has at most a few hundred members and a profile is six scalar
  /// fields, so TTL/LRU machinery isn't justified, and users_public is
  /// viewer-independent so it survives sign-out safely.
  final Map<String, PublicProfile> _profileCache = {};

  SessionsRepositoryImpl(this._remote);

  @override
  Stream<List<SessionModel>> watchUpcoming(UserModel viewer,
      {required bool emailVerified}) {
    // Firestore rules require email_verified == true to read sessions —
    // return an empty list instead of hitting PERMISSION_DENIED. Inactive
    // (unpaid) players still see sessions; joinSession refuses them.
    if (!emailVerified) return Stream.value(const []);
    // Players must provide gender + date of birth before we can match them to
    // gender-/age-gated sessions. Coaches manage all sessions, so they're
    // exempt. The sessions tab surfaces a "complete your profile" prompt.
    if (!viewer.isCoach && !viewer.hasCompleteProfile) {
      return Stream.value(const []);
    }
    return _remote.watchUpcoming(viewer);
  }

  @override
  Stream<SessionModel?> watchSession(String id) => _remote.watchSession(id);

  @override
  Stream<SessionModel?> watchArchivedSession(String id) =>
      _remote.watchArchivedSession(id);

  @override
  Stream<List<SessionModel>> watchHistory(UserModel viewer,
          {int limit = 100}) =>
      _remote.watchHistory(viewer, limit: limit);

  @override
  Future<Map<String, PublicProfile>> fetchPublicProfiles(
      List<String> uids) async {
    final fresh = await _remote.fetchPublicProfiles(uids);
    _profileCache.addAll(fresh);
    return fresh;
  }

  @override
  Map<String, PublicProfile> cachedProfiles(List<String> uids) => {
        for (final uid in uids)
          if (_profileCache[uid] != null) uid: _profileCache[uid]!,
      };

  @override
  Stream<Map<String, PublicProfile>> watchPublicProfiles(List<String> uids) =>
      cacheThenServer(
        (options) => _remote.fetchPublicProfiles(uids, options),
        isUsable: (profiles) => profiles.isNotEmpty,
      ).map((profiles) {
        _profileCache.addAll(profiles);
        return profiles;
      });

  @override
  Future<Map<String, PublicProfile>> fetchPublicProfilesCached(
      List<String> uids) async {
    final missing = _missingFromMemory(uids);
    if (missing.isEmpty) return cachedProfiles(uids);

    // On-device copy first: after a cold start the memory cache is empty, and
    // waiting on the server for every avatar is what makes a slow network
    // feel broken. Whatever the disk had is refreshed in the background so
    // the next read is fresh; only uids the disk lacks block on the server.
    final fromDisk = await _diskProfiles(missing);
    _profileCache.addAll(fromDisk);
    if (fromDisk.isNotEmpty) {
      unawaited(fetchPublicProfiles(fromDisk.keys.toList())
          .then((_) {}, onError: (_) {}));
    }
    final stillMissing = [
      for (final uid in missing)
        if (!fromDisk.containsKey(uid)) uid,
    ];
    if (stillMissing.isNotEmpty) {
      _profileCache.addAll(await _remote.fetchPublicProfiles(stillMissing));
    }
    return cachedProfiles(uids);
  }

  @override
  Stream<Map<String, PublicProfile>> watchPublicProfilesCached(
      List<String> uids) async* {
    final missing = _missingFromMemory(uids);
    if (missing.isEmpty) {
      yield cachedProfiles(uids);
      return;
    }
    await for (final _ in watchPublicProfiles(missing)) {
      yield cachedProfiles(uids);
    }
  }

  List<String> _missingFromMemory(List<String> uids) => [
        for (final uid in {...uids})
          if (!_profileCache.containsKey(uid)) uid,
      ];

  Future<Map<String, PublicProfile>> _diskProfiles(List<String> uids) async {
    try {
      return await _remote.fetchPublicProfiles(
          uids, const GetOptions(source: Source.cache));
    } catch (_) {
      return const {};
    }
  }

  @override
  Stream<PublicProfile?> watchPublicProfile(String uid) =>
      _remote.watchPublicProfile(uid).map((profile) {
        if (profile != null) _profileCache[uid] = profile;
        return profile;
      });

  @override
  Future<List<DateTime>> fetchAttendedTimes(String uid) =>
      _remote.fetchAttendedTimes(uid);

  @override
  Stream<List<DateTime>> watchAttendedTimes(String uid) => cacheThenServer(
        (options) => _remote.fetchAttendedTimes(uid, options: options),
        isUsable: (times) => times.isNotEmpty,
      );

  @override
  Future<DateTime?> fetchLastAttendedTime(String uid) =>
      _remote.fetchLastAttendedTime(uid);

  @override
  Future<List<SessionModel>> fetchAttendedSessions(String uid,
          {int limit = 20}) =>
      _remote.fetchAttendedSessions(uid, limit: limit);

  @override
  Future<List<SessionModel>> fetchCoachRecentSessions(String coachUid,
          {int limit = 20}) =>
      _remote.fetchCoachRecentSessions(coachUid, limit: limit);

  @override
  Stream<List<SessionModel>> watchCoachRecentSessions(String coachUid,
          {int limit = 20}) =>
      cacheThenServer(
        (options) => _remote.fetchCoachRecentSessions(coachUid,
            limit: limit, options: options),
        isUsable: (sessions) => sessions.isNotEmpty,
      );

  @override
  Future<void> create(SessionModel session, {int? designIndex}) =>
      _remote.create(session, designIndex: designIndex);

  @override
  Future<JoinResult> join(String sessionId) async {
    final String status;
    try {
      status = await _remote.join(sessionId);
    } on FirebaseFunctionsException catch (e) {
      throw SessionActionException(e.code, e.message);
    }
    switch (status) {
      case 'waitlisted':
        return JoinResult.waitlisted;
      case 'already_joined':
        return JoinResult.alreadyJoined;
      case 'already_waitlisted':
        return JoinResult.alreadyWaitlisted;
      default:
        return JoinResult.joined;
    }
  }

  @override
  Future<void> leave(String sessionId) => _wrap(() => _remote.leave(sessionId));

  @override
  Future<void> cancel(String sessionId) =>
      _wrap(() => _remote.cancel(sessionId));

  @override
  Future<void> updateCapacity(String sessionId,
          {int? newMaxPlayers, int? newWaitlistSize}) =>
      _wrap(() => _remote.updateCapacity(sessionId,
          newMaxPlayers: newMaxPlayers, newWaitlistSize: newWaitlistSize));

  @override
  Future<void> makeSessionPublic(String sessionId,
          {required String gender,
          required int minAge,
          required int maxAge}) =>
      _wrap(() => _remote.makeSessionPublic(sessionId,
          gender: gender, minAge: minAge, maxAge: maxAge));

  @override
  Future<void> updateSessionMembers(
          String sessionId, List<String> memberIds) =>
      _wrap(() => _remote.updateSessionMembers(sessionId, memberIds));

  @override
  Future<void> updateSessionCoaches(
          String sessionId, List<String> coachIds) =>
      _wrap(() => _remote.updateSessionCoaches(sessionId, coachIds));

  @override
  Future<void> updateSessionTime(String sessionId, DateTime newStart) =>
      _wrap(() => _remote.updateSessionTime(sessionId, newStart));

  @override
  Future<void> markAttended(String sessionId, String userId, bool attended) =>
      _wrap(() => _remote.markAttended(sessionId, userId, attended));

  @override
  Future<void> removeAttendee(String sessionId, String userId) =>
      _wrap(() => _remote.removeAttendee(sessionId, userId));

  @override
  Future<void> addAttendees(String sessionId, List<String> userIds) =>
      _wrap(() => _remote.addAttendees(sessionId, userIds));

  @override
  Future<void> confirmAttendance(String sessionId, List<String> presentUids) =>
      _wrap(() => _remote.confirmAttendance(sessionId, presentUids));

  @override
  Future<void> endorse(String sessionId, String userId) =>
      _wrap(() => _remote.endorse(sessionId, userId));

  @override
  Stream<Set<String>> watchMyEndorsements(String sessionId, String myUid) =>
      _remote.watchMyEndorsements(sessionId, myUid);

  @override
  Stream<Lineup> watchLineup(String sessionId) => _remote
      .watchLineup(sessionId)
      .map((lineup) => lineup ?? Lineup.empty());

  @override
  Future<void> saveLineup(String sessionId, Lineup lineup, String byUid) =>
      _remote.saveLineup(sessionId, lineup, byUid);

  @override
  Future<void> archiveExpiredNow() => _remote.archiveExpiredNow();

  Future<void> _wrap(Future<void> Function() call) async {
    try {
      await call();
    } on FirebaseFunctionsException catch (e) {
      throw SessionActionException(e.code);
    }
  }
}
