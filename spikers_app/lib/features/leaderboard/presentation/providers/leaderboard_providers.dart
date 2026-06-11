import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
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

final allTimeLeaderboardProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>(
  (ref) => ref.watch(leaderboardRepositoryProvider).fetchAllTime(),
);

final monthlyLeaderboardProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>(
  (ref) => ref.watch(leaderboardRepositoryProvider).fetchMonthly(),
);
