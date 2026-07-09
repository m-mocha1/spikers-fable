import '../entities/announcement.dart';

abstract class AnnouncementsRepository {
  /// Newest [limit] announcements, newest first. Audience filtering for
  /// players happens client-side (see visibleAnnouncementsProvider); coaches
  /// see the full list. Bounded because this stream stays alive for the whole
  /// app run (it feeds the bell badge) — anything older than the newest
  /// [limit] simply drops off the list screen.
  Stream<List<AnnouncementModel>> watchAll({int limit});

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
