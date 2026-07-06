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
  int endorsementCount,
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

  /// Archived sessions, most recently ended first. Players only see their
  /// own gender (or mixed) sessions; coaches/admins see all genders.
  Stream<List<SessionModel>> watchHistory(UserModel viewer, {int limit});

  /// Batched users_public lookup (whereIn chunking handled inside).
  Future<Map<String, PublicProfile>> fetchPublicProfiles(List<String> uids);

  /// Live single users_public profile for [uid]; null until the mirror exists.
  /// Powers the profile's own reactive attendance/endorsement counts so they
  /// refresh without a reload.
  Stream<PublicProfile?> watchPublicProfile(String uid);

  /// Start times of sessions where [uid] was marked attended (recent first,
  /// bounded) — drives the weekly attendance streak on the profile.
  Future<List<DateTime>> fetchAttendedTimes(String uid);

  /// Start time of the most recent session [uid] attended, or null if they
  /// never attended — feeds the attendance export's "last session" column.
  Future<DateTime?> fetchLastAttendedTime(String uid);

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

  /// Records a single endorsement from the signed-in user to [userId] for
  /// [sessionId] (Overwatch-style peer endorsement). Idempotent server-side.
  /// Throws [SessionActionException].
  Future<void> endorse(String sessionId, String userId);

  /// Target uids the signed-in user ([myUid]) has already endorsed in
  /// [sessionId] — drives the endorse-button state. Live via snapshots.
  Stream<Set<String>> watchMyEndorsements(String sessionId, String myUid);

  /// Best-effort on-demand archival; never throws (the scheduled cleanup
  /// function archives expired sessions anyway).
  Future<void> archiveExpiredNow();
}
