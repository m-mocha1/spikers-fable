import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import 'package:spikers_app/features/sessions/domain/attendance_prompt.dart';
import 'package:spikers_app/features/sessions/domain/entities/recurring_session_model.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_template_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/sessions_remote_datasource.dart';
import '../../data/repositories/recurring_sessions_repository_impl.dart';
import '../../data/repositories/session_chat_repository_impl.dart';
import '../../data/repositories/sessions_repository_impl.dart';
import '../../data/repositories/templates_repository_impl.dart';
import '../../domain/repositories/recurring_sessions_repository.dart';
import '../../domain/repositories/session_chat_repository.dart';
import '../../domain/repositories/sessions_repository.dart';
import '../../domain/repositories/templates_repository.dart';

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

final templatesRepositoryProvider = Provider<TemplatesRepository>(
  (ref) => TemplatesRepositoryImpl(ref.watch(_sessionsDataSourceProvider)),
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
  final viewer = ref.watch(currentUserProvider).value;
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
final facepileProfilesProvider = FutureProvider.autoDispose
    .family<List<PublicProfile>, String>((ref, joinedUids) async {
  final uids = joinedUids.split(',').where((u) => u.isNotEmpty).toList();
  if (uids.isEmpty) return const [];
  // Cached variant: facepiles tolerate slightly stale names/photos, and the
  // shared cache stops every card (and every rebuild) re-reading the same
  // players from Firestore.
  final map = await ref
      .watch(sessionsRepositoryProvider)
      .fetchPublicProfilesCached(uids);
  return [
    for (final uid in uids)
      if (map[uid] != null) map[uid]!,
  ];
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
  final uid = ref.watch(currentUserProvider).value?.uid;
  if (uid == null) return Stream.value(const <String>{});
  return ref
      .watch(sessionsRepositoryProvider)
      .watchMyEndorsements(sessionId, uid);
});

/// Archived sessions visible to the signed-in user: players only see their
/// own gender (or mixed); coaches/admins see all. Empty while signed out.
final sessionsHistoryProvider =
    StreamProvider.autoDispose<List<SessionModel>>((ref) {
  final viewer = ref.watch(currentUserProvider).value;
  if (viewer == null) return Stream.value(const []);
  return ref.watch(sessionsRepositoryProvider).watchHistory(viewer);
});

/// Sessions the signed-in coach still needs to take attendance for — ended
/// recently, owned by them, and not yet confirmed. Empty for players/signed
/// out. Drives the "N sessions need attendance" banner on the sessions tab;
/// invalidate it after a confirm to refresh the count.
final coachAttendanceTodoProvider =
    FutureProvider.autoDispose<List<SessionModel>>((ref) async {
  final viewer = ref.watch(currentUserProvider).value;
  if (viewer == null || !viewer.isCoach) return const [];
  final sessions = await ref
      .watch(sessionsRepositoryProvider)
      .fetchCoachRecentSessions(viewer.uid);
  return coachSessionsNeedingAttendance(
    sessions: sessions,
    uid: viewer.uid,
    now: DateTime.now(),
  );
});

final templatesProvider =
    StreamProvider.autoDispose<List<SessionTemplate>>((ref) {
  final uid = ref.watch(currentUserProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(templatesRepositoryProvider).watch(uid);
});

final recurringSessionsProvider =
    StreamProvider.autoDispose<List<RecurringSessionModel>>((ref) {
  final uid = ref.watch(currentUserProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(recurringSessionsRepositoryProvider).watchForCoach(uid);
});
