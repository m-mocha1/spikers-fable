import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/features/announcements/data/datasources/announcements_remote_datasource.dart';
import 'package:spikers_app/features/announcements/data/repositories/announcements_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore db;
  late AnnouncementsRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo =
        AnnouncementsRepositoryImpl(AnnouncementsRemoteDataSource(db));
  });

  test('create then watchAll returns newest first', () async {
    await repo.create(
        title: 'first',
        body: 'b1',
        authorId: 'c1',
        authorName: 'Coach',
        audience: 'all');
    // fake server timestamps can collide within the same instant; nudge.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.create(
        title: 'second',
        body: 'b2',
        authorId: 'c1',
        authorName: 'Coach',
        audience: 'all');

    final list = await repo.watchAll().first;
    expect(list.length, 2);
    expect(list.first.title, 'second');
    expect(list.last.title, 'first');
  });

  test('create persists the chosen audience', () async {
    await repo.create(
        title: 't',
        body: 'b',
        authorId: 'c1',
        authorName: 'Coach',
        audience: 'female');
    final a = (await repo.watchAll().first).first;
    expect(a.audience, 'female');
  });

  test('edit updates fields including audience, delete removes the doc',
      () async {
    await repo.create(
        title: 'orig',
        body: 'b',
        authorId: 'c1',
        authorName: 'Coach',
        audience: 'all');
    final id = (await repo.watchAll().first).first.id;

    await repo.edit(id: id, title: 'edited', body: 'b2', audience: 'male');
    final edited = (await repo.watchAll().first).first;
    expect(edited.title, 'edited');
    expect(edited.body, 'b2');
    expect(edited.audience, 'male');

    await repo.delete(id);
    expect(await repo.watchAll().first, isEmpty);
  });

  test('watchAll respects the limit, keeping the newest items', () async {
    for (final title in ['oldest', 'middle', 'newest']) {
      await repo.create(
          title: title,
          body: 'b',
          authorId: 'c1',
          authorName: 'Coach',
          audience: 'all');
      // fake server timestamps can collide within the same instant; nudge.
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    final list = await repo.watchAll(limit: 2).first;
    expect(list.map((a) => a.title), ['newest', 'middle']);
  });

  test('markRead stamps lastSeenAnnouncementsAt on the user doc', () async {
    await db.collection('users').doc('u1').set({'name': 'x'});
    await repo.markRead('u1');
    final doc = await db.collection('users').doc('u1').get();
    expect(doc.data()!['lastSeenAnnouncementsAt'], isNotNull);
  });
}
