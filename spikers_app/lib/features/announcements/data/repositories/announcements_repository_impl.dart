import '../../domain/entities/announcement.dart';
import '../../domain/repositories/announcements_repository.dart';
import '../datasources/announcements_remote_datasource.dart';

class AnnouncementsRepositoryImpl implements AnnouncementsRepository {
  final AnnouncementsRemoteDataSource _remote;

  AnnouncementsRepositoryImpl(this._remote);

  @override
  Stream<List<AnnouncementModel>> watchAll() => _remote.watchAll();

  @override
  Stream<DateTime?> watchLatestAt() => _remote.watchLatestAt();

  @override
  Future<void> markRead(String uid) => _remote.markRead(uid);

  @override
  Future<void> create({
    required String title,
    required String body,
    required String authorId,
    required String authorName,
  }) =>
      _remote.create(
          title: title, body: body, authorId: authorId, authorName: authorName);

  @override
  Future<void> edit(
          {required String id, required String title, required String body}) =>
      _remote.edit(id: id, title: title, body: body);

  @override
  Future<void> delete(String id) => _remote.delete(id);
}
