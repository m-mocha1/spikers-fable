import 'package:cloud_functions/cloud_functions.dart';

import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import '../../domain/repositories/sessions_repository.dart';
import '../datasources/sessions_remote_datasource.dart';

class SessionsRepositoryImpl implements SessionsRepository {
  final SessionsRemoteDataSource _remote;

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
  Stream<List<SessionModel>> watchHistory({int limit = 100}) =>
      _remote.watchHistory(limit: limit);

  @override
  Future<Map<String, PublicProfile>> fetchPublicProfiles(List<String> uids) =>
      _remote.fetchPublicProfiles(uids);

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
  Future<void> archiveExpiredNow() => _remote.archiveExpiredNow();

  Future<void> _wrap(Future<void> Function() call) async {
    try {
      await call();
    } on FirebaseFunctionsException catch (e) {
      throw SessionActionException(e.code);
    }
  }
}
