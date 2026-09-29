import 'dart:async';

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

/// Which board is shown: 0 = games (attendance), 1 = endorsements. Same
/// per-visit reset as [leaderboardTabProvider].
final leaderboardBoardProvider = StateProvider.autoDispose<int>((ref) => 0);

/// How long a board stays in memory after the leaderboard screen stops
/// watching it. Boards are a few hundred docs and change slowly, so flipping
/// between tabs/boards or re-opening the screen shouldn't re-download them.
const _boardCacheDuration = Duration(minutes: 5);

/// Keeps an autoDispose provider alive for [_boardCacheDuration] after its
/// last listener leaves; a listener returning within that window cancels the
/// countdown. Pull-to-refresh still works — `ref.invalidate` bypasses this.
void _keepBoardCached(Ref ref) {
  final link = ref.keepAlive();
  Timer? timer;
  ref.onCancel(() => timer = Timer(_boardCacheDuration, link.close));
  ref.onResume(() => timer?.cancel());
  ref.onDispose(() => timer?.cancel());
}

/// Boards are viewer-aware: players only see their own gender; coaches and
/// admins see everyone. Empty while signed out. Cache-first streams: the
/// board from the last visit shows at once, then the fresh one replaces it.
final allTimeLeaderboardProvider =
    StreamProvider.autoDispose<List<LeaderboardEntry>>((ref) {
  final viewer = ref.watch(queryViewerProvider);
  if (viewer == null) return Stream.value(const []);
  _keepBoardCached(ref);
  return ref.watch(leaderboardRepositoryProvider).watchAllTime(viewer);
});

final monthlyLeaderboardProvider =
    StreamProvider.autoDispose<List<LeaderboardEntry>>((ref) {
  final viewer = ref.watch(queryViewerProvider);
  if (viewer == null) return Stream.value(const []);
  _keepBoardCached(ref);
  return ref.watch(leaderboardRepositoryProvider).watchMonthly(viewer);
});

final endorsementLeaderboardProvider =
    StreamProvider.autoDispose<List<LeaderboardEntry>>((ref) {
  final viewer = ref.watch(queryViewerProvider);
  if (viewer == null) return Stream.value(const []);
  _keepBoardCached(ref);
  return ref.watch(leaderboardRepositoryProvider).watchEndorsements(viewer);
});
