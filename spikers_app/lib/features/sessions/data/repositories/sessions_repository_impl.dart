import 'package:cloud_functions/cloud_functions.dart';

import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
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
    // Firestore rules require email_verified == true to read sessions, and
    // unpaid players are not allowed in — return an empty list instead of
    // hitting PERMISSION_DENIED.
    if (!emailVerified) return Stream.value(const []);
    if (!viewer.isCoach && !viewer.isPaid) return Stream.value(const []);
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
  Future<Map<String, PublicProfile>> fetchPublicProfilesCached(
      List<String> uids) async {
    final missing = [
      for (final uid in {...uids})
        if (!_profileCache.containsKey(uid)) uid,
    ];
    if (missing.isNotEmpty) {
      _profileCache.addAll(await _remote.fetchPublicProfiles(missing));
    }
    return cachedProfiles(uids);
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
  Future<DateTime?> fetchLastAttendedTime(String uid) =>
      _remote.fetchLastAttendedTime(uid);

  @override
  Future<void> create(SessionModel session) => _remote.create(session);

  @override
  Future<JoinResult> join(String sessionId) async {
    final String status;
    try {
      status = await _remote.join(sessionId);
    } on FirebaseFunctionsException catch (e) {
      throw SessionActionException(e.code);
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
  Future<void> markAttended(String sessionId, String userId, bool attended) =>
      _wrap(() => _remote.markAttended(sessionId, userId, attended));

  @override
  Future<void> removeAttendee(String sessionId, String userId) =>
      _wrap(() => _remote.removeAttendee(sessionId, userId));

  @override
  Future<void> endorse(String sessionId, String userId) =>
      _wrap(() => _remote.endorse(sessionId, userId));

  @override
  Stream<Set<String>> watchMyEndorsements(String sessionId, String myUid) =>
      _remote.watchMyEndorsements(sessionId, myUid);

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
