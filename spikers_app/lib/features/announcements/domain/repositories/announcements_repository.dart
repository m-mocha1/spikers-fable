import '../entities/announcement.dart';

abstract class AnnouncementsRepository {
  /// All announcements, newest first.
  Stream<List<AnnouncementModel>> watchAll();

  /// createdAt of the newest announcement; null when there are none.
  /// Drives the unread badge.
  Stream<DateTime?> watchLatestAt();

  /// Stamps the user's lastSeenAnnouncementsAt to now.
  Future<void> markRead(String uid);

  Future<void> create({
    required String title,
    required String body,
    required String authorId,
    required String authorName,
  });

  Future<void> edit({
    required String id,
    required String title,
    required String body,
  });

  Future<void> delete(String id);
}
