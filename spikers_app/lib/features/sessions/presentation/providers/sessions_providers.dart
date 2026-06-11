import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../models/recurring_session_model.dart';
import '../../../../models/session_model.dart';
import '../../../../models/session_template_model.dart';
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

final archivedSessionProvider =
    StreamProvider.autoDispose.family<SessionModel?, String>(
  (ref, id) => ref.watch(sessionsRepositoryProvider).watchArchivedSession(id),
);

final sessionsHistoryProvider =
    StreamProvider.autoDispose<List<SessionModel>>(
  (ref) => ref.watch(sessionsRepositoryProvider).watchHistory(),
);

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
