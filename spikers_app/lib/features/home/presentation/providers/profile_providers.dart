import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/attendance_streak.dart';
import '../../../sessions/domain/repositories/sessions_repository.dart';
import '../../../sessions/presentation/providers/sessions_providers.dart';

/// Live view of the signed-in user's public mirror (users_public/{uid}).
/// Streaming (not a one-shot fetch) so the profile's stats update the moment a
/// coach marks attendance or an endorsement lands — no reload/tab-revisit
/// needed. Both counts below derive from this single snapshot listener.
final myPublicProfileProvider =
    StreamProvider.autoDispose.family<PublicProfile?, String>((ref, uid) {
  return ref.watch(sessionsRepositoryProvider).watchPublicProfile(uid);
});

/// The signed-in user's lifetime attendance ("games played"), derived live
/// from [myPublicProfileProvider]. `UserModel` itself carries no attendance
/// field, so it comes from the public mirror.
final myAttendanceCountProvider =
    Provider.autoDispose.family<AsyncValue<int>, String>((ref, uid) {
  return ref
      .watch(myPublicProfileProvider(uid))
      .whenData((p) => p?.attendanceCount ?? 0);
});

/// Consecutive attended weeks for the signed-in user (see [AttendanceStreak]
/// for the week/grace semantics). Built on the repo's bounded attended-times
/// query, so it costs one indexed read per profile visit.
final myStreakProvider =
    FutureProvider.autoDispose.family<int, String>((ref, uid) async {
  final times =
      await ref.watch(sessionsRepositoryProvider).fetchAttendedTimes(uid);
  return AttendanceStreak.weeklyStreak(times);
});

/// The signed-in user's lifetime endorsement count, derived live from
/// [myPublicProfileProvider] — same source as [myAttendanceCountProvider].
final myEndorsementCountProvider =
    Provider.autoDispose.family<AsyncValue<int>, String>((ref, uid) {
  return ref
      .watch(myPublicProfileProvider(uid))
      .whenData((p) => p?.endorsementCount ?? 0);
});
