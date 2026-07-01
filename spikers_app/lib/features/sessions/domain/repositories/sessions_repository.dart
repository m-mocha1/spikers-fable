import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';

/// Thrown when a session Cloud Function call is rejected. [code] is the
/// FirebaseFunctionsException code — presentation maps it to a localized
/// message.
class SessionActionException implements Exception {
  final String code;
  const SessionActionException(this.code);

  @override
  String toString() => 'SessionActionException($code)';
}

enum JoinResult { joined, waitlisted, alreadyJoined, alreadyWaitlisted }

/// A users_public profile row used for attendee/sender display.
typedef PublicProfile = ({
  String name,
  String photoUrl,
  String gender,
  int attendanceCount,
  bool injured,
});

abstract class SessionsRepository {
  /// Upcoming sessions visible to [viewer]:
  /// - unverified users and unpaid non-coaches see an empty list (Firestore
  ///   rules would reject the query anyway);
  /// - non-coaches only see their gender (or mixed) within their age range.
  Stream<List<SessionModel>> watchUpcoming(UserModel viewer,
      {required bool emailVerified});

  /// Live session document; null once it is deleted/archived.
  Stream<SessionModel?> watchSession(String id);

  /// Archived copy in sessions_history; null while not yet archived.
  Stream<SessionModel?> watchArchivedSession(String id);

  /// Archived sessions, most recently ended first.
  Stream<List<SessionModel>> watchHistory({int limit});

  /// Batched users_public lookup (whereIn chunking handled inside).
  Future<Map<String, PublicProfile>> fetchPublicProfiles(List<String> uids);

  /// Creates the session with a random card design.
  Future<void> create(SessionModel session);

  /// Transactional join; falls back to the waitlist when full.
  /// Throws [SessionActionException].
  Future<JoinResult> join(String sessionId);

  /// Throws [SessionActionException].
  Future<void> leave(String sessionId);

  /// Coach-only delete; attendees are notified server-side.
  /// Throws [SessionActionException].
  Future<void> cancel(String sessionId);

  /// Throws [SessionActionException].
  Future<void> updateCapacity(String sessionId,
      {int? newMaxPlayers, int? newWaitlistSize});

  /// Throws [SessionActionException].
  Future<void> markAttended(String sessionId, String userId, bool attended);

  /// Owner-coach or admin removes a player from the session (attendee or
  /// waitlist). Throws [SessionActionException].
  Future<void> removeAttendee(String sessionId, String userId);

  /// Best-effort on-demand archival; never throws (the scheduled cleanup
  /// function archives expired sessions anyway).
  Future<void> archiveExpiredNow();
}
