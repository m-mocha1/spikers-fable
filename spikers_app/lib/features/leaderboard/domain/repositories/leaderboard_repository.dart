import '../entities/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  /// Top players by lifetime attendance, highest first. Entries with a
  /// non-positive count are excluded.
  Future<List<LeaderboardEntry>> fetchAllTime();

  /// Attendance counts for sessions starting this calendar month, highest
  /// first. Counts both live and archived sessions.
  Future<List<LeaderboardEntry>> fetchMonthly();
}
