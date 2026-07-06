import 'package:spikers_app/features/auth/domain/entities/user_model.dart';

import '../entities/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  /// Top players by lifetime attendance, highest first. Entries with a
  /// non-positive count are excluded. Players only see (and rank within)
  /// their own gender; coaches/admins see everyone — entries carry the
  /// gender so the UI can offer a tag filter.
  Future<List<LeaderboardEntry>> fetchAllTime(UserModel viewer);

  /// Attendance counts for sessions starting this calendar month, highest
  /// first. Counts both live and archived sessions. Same gender visibility
  /// rule as [fetchAllTime].
  Future<List<LeaderboardEntry>> fetchMonthly(UserModel viewer);
}
