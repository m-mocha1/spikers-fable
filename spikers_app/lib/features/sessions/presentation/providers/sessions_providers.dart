import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import 'package:spikers_app/features/sessions/domain/attendance_prompt.dart';
import 'package:spikers_app/features/sessions/domain/entities/player_group_model.dart';
import 'package:spikers_app/features/sessions/domain/entities/recurring_session_model.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/sessions_remote_datasource.dart';
import '../../data/repositories/player_groups_repository_impl.dart';
import '../../data/repositories/recurring_sessions_repository_impl.dart';
import '../../data/repositories/session_chat_repository_impl.dart';
import '../../data/repositories/sessions_repository_impl.dart';
import '../../domain/repositories/player_groups_repository.dart';
import '../../domain/repositories/recurring_sessions_repository.dart';
import '../../domain/repositories/session_chat_repository.dart';
import '../../domain/repositories/sessions_repository.dart';

final _sessionsDataSourceProvider = Provider<SessionsRemoteDataSource>(
  (ref) => SessionsRemoteDataSource(
    ref.watch(firestoreProvider),
    ref.watch(firebaseFunctionsProvider),
  ),
);

final sessionsRepositoryProvider = Provider<SessionsRepository>(
  (ref) => SessionsRepositoryImpl(ref.watch(_sessionsDataSourceProvider)),
);

final sessionChatRepositoryProvider = Provider<SessionChatRepository>(
  (ref) => SessionChatRepositoryImpl(ref.watch(_sessionsDataSourceProvider)),
);

final playerGroupsRepositoryProvider = Provider<PlayerGroupsRepository>(
  (ref) => PlayerGroupsRepositoryImpl(ref.watch(_sessionsDataSourceProvider)),
);

final recurringSessionsRepositoryProvider =
    Provider<RecurringSessionsRepository>(
  (ref) =>
      RecurringSessionsRepositoryImpl(ref.watch(_sessionsDataSourceProvider)),
);

/// Upcoming sessions for the signed-in user; empty while signed out.
/// Not autoDispose: the sessions tab is the home screen's default tab and
/// the old controller kept this listener alive for the whole session.
final upcomingSessionsProvider = StreamProvider<List<SessionModel>>((ref) {
  final viewer = ref.watch(queryViewerProvider);
  if (viewer == null) return Stream.value(const []);
  final repo = ref.watch(sessionsRepositoryProvider);
  final emailVerified = ref.watch(authRepositoryProvider).isEmailVerified;
  return repo.watchUpcoming(viewer, emailVerified: emailVerified);
});

final sessionProvider = StreamProvider.autoDispose.family<SessionModel?, String>(
  (ref, id) => ref.watch(sessionsRepositoryProvider).watchSession(id),
);

/// Public profiles for a card facepile, keyed by a comma-joined uid string —
/// family params need value equality, which a `List<String>` doesn't have.
/// Returns profiles in the same order as the incoming uids (attendee order).
final facepileProfilesProvider = StreamProvider.autoDispose
    .family<List<PublicProfile>, String>((ref, joinedUids) {
  final uids = joinedUids.split(',').where((u) => u.isNotEmpty).toList();
  if (uids.isEmpty) return Stream.value(const []);
  // Cached variant: facepiles tolerate slightly stale names/photos, and the
  // shared cache stops every card (and every rebuild) re-reading the same
  // players from Firestore. Streamed so the on-device copy paints first on a
  // cold start instead of every card waiting on the network.
  return ref
      .watch(sessionsRepositoryProvider)
      .watchPublicProfilesCached(uids)
      .map((map) => [
            for (final uid in uids)
              if (map[uid] != null) map[uid]!,
          ]);
});

final archivedSessionProvider =
    StreamProvider.autoDispose.family<SessionModel?, String>(
  (ref, id) => ref.watch(sessionsRepositoryProvider).watchArchivedSession(id),
);

/// Target uids the signed-in user has already endorsed in [sessionId].
/// Empty while signed out. Drives the endorse-button state on the session
/// detail screen.
final myEndorsementsProvider =
    StreamProvider.autoDispose.family<Set<String>, String>((ref, sessionId) {
  final uid = ref.watch(queryViewerProvider)?.uid;
  if (uid == null) return Stream.value(const <String>{});
  return ref
      .watch(sessionsRepositoryProvider)
      .watchMyEndorsements(sessionId, uid);
});

/// Archived sessions visible to the signed-in user: players only see their
/// own gender (or mixed); coaches/admins see all. Empty while signed out.
///
/// Paged: streams the newest [historyLimitProvider] sessions, which the
/// history screen grows as the user reaches the end of the list.
final sessionsHistoryProvider =
    StreamProvider.autoDispose<List<SessionModel>>((ref) {
  final viewer = ref.watch(queryViewerProvider);
  if (viewer == null) return Stream.value(const []);
  final limit = ref.watch(historyLimitProvider);
  return ref
      .watch(sessionsRepositoryProvider)
      .watchHistory(viewer, limit: limit);
});

/// Sessions per history page. Small so a slow network paints the first
/// screenful quickly instead of downloading the whole archive up front.
const kHistoryPageSize = 20;

/// How many history sessions [sessionsHistoryProvider] streams. Resets with
/// the history screen (autoDispose).
final historyLimitProvider =
    StateProvider.autoDispose<int>((ref) => kHistoryPageSize);

/// Sessions the signed-in coach still needs to take attendance for — ended
/// recently, owned by them, and not yet confirmed. Empty for players/signed
/// out. Drives the "N sessions need attendance" banner on the sessions tab;
/// invalidate it after a confirm to refresh the count.
final coachAttendanceTodoProvider =
    StreamProvider.autoDispose<List<SessionModel>>((ref) {
  final viewer = ref.watch(queryViewerProvider);
  if (viewer == null || !viewer.isCoach) return Stream.value(const []);
  return ref
      .watch(sessionsRepositoryProvider)
      .watchCoachRecentSessions(viewer.uid)
      .map((sessions) => coachSessionsNeedingAttendance(
            sessions: sessions,
            uid: viewer.uid,
            now: DateTime.now(),
          ));
});

/// The shared team library of player groups, most-recently-updated first.
/// Empty for players / signed-out users (reads require coach/admin — see
/// firestore.rules). Drives the quick-group rail in the create-session flow
/// and the member picker.
final playerGroupsProvider =
    StreamProvider.autoDispose<List<PlayerGroup>>((ref) {
  final user = ref.watch(queryViewerProvider);
  if (user == null || !user.isCoach) return Stream.value(const []);
  return ref.watch(playerGroupsRepositoryProvider).watch();
});

final recurringSessionsProvider =
    StreamProvider.autoDispose<List<RecurringSessionModel>>((ref) {
  final uid = ref.watch(queryViewerProvider)?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(recurringSessionsRepositoryProvider).watchForCoach(uid);
});
