import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/leaderboard_remote_datasource.dart';
import '../../data/repositories/leaderboard_repository_impl.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
  (ref) => LeaderboardRepositoryImpl(
    LeaderboardRemoteDataSource(ref.watch(firestoreProvider)),
  ),
);

/// 0 = this month, 1 = all time. autoDispose resets the tab when the screen
/// is left, matching the old per-visit GetX binding.
final leaderboardTabProvider = StateProvider.autoDispose<int>((ref) => 0);

/// Boards are viewer-aware: players only see their own gender; coaches and
/// admins see everyone. Empty while signed out.
final allTimeLeaderboardProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) {
  final viewer = ref.watch(currentUserProvider).value;
  if (viewer == null) return Future.value(const []);
  return ref.watch(leaderboardRepositoryProvider).fetchAllTime(viewer);
});

final monthlyLeaderboardProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) {
  final viewer = ref.watch(currentUserProvider).value;
  if (viewer == null) return Future.value(const []);
  return ref.watch(leaderboardRepositoryProvider).fetchMonthly(viewer);
});
