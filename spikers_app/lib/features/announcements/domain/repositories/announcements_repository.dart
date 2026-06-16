import '../entities/announcement.dart';

abstract class AnnouncementsRepository {
  /// All announcements, newest first. Audience filtering for players happens
  /// client-side (see visibleAnnouncementsProvider); coaches see the full list.
  Stream<List<AnnouncementModel>> watchAll();

  /// Stamps the user's lastSeenAnnouncementsAt to now.
  Future<void> markRead(String uid);

  Future<void> create({
    required String title,
    required String body,
    required String authorId,
    required String authorName,
    required String audience,
  });

  Future<void> edit({
    required String id,
    required String title,
    required String body,
    required String audience,
  });

  Future<void> delete(String id);
}
