import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/attendance_streak.dart';
import '../../../sessions/presentation/providers/sessions_providers.dart';

/// The signed-in user's lifetime attendance ("games played"), read from their
/// public mirror through the existing [SessionsRepository.fetchPublicProfiles]
/// — `UserModel` itself carries no attendance field, and this reuses the repo
/// method already used to render attendee counts, so no new data layer.
final myAttendanceCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, uid) async {
  final repo = ref.watch(sessionsRepositoryProvider);
  final profiles = await repo.fetchPublicProfiles([uid]);
  return profiles[uid]?.attendanceCount ?? 0;
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
