import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/features/announcements/domain/entities/announcement.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<DocumentSnapshot> writeAndRead(Map<String, dynamic> data) async {
    final ref = db.collection('announcements').doc('a1');
    await ref.set(data);
    return ref.get();
  }

  group('AnnouncementModel', () {
    test('parses a complete doc', () async {
      final created = DateTime(2026, 3, 4, 5, 6);
      final snap = await writeAndRead({
        'title': 'Training moved',
        'body': 'We start at 19:00 this week.',
        'authorId': 'coach1',
        'authorName': 'Coach Dana',
        'audience': 'female',
        'createdAt': Timestamp.fromDate(created),
      });
      final parsed = AnnouncementModel.fromDoc(snap);
      expect(parsed.id, 'a1');
      expect(parsed.title, 'Training moved');
      expect(parsed.body, 'We start at 19:00 this week.');
      expect(parsed.authorId, 'coach1');
      expect(parsed.authorName, 'Coach Dana');
      expect(parsed.audience, 'female');
      expect(parsed.createdAt, created);
    });

    test('missing createdAt falls back to now instead of throwing', () async {
      final before = DateTime.now();
      final snap = await writeAndRead({'title': 't', 'body': 'b'});
      final parsed = AnnouncementModel.fromDoc(snap);
      expect(parsed.createdAt.isBefore(before), isFalse);
      expect(parsed.authorId, '');
      expect(parsed.authorName, '');
    });

    test('missing audience defaults to "all" (legacy docs stay visible)',
        () async {
      final snap = await writeAndRead({'title': 't', 'body': 'b'});
      final parsed = AnnouncementModel.fromDoc(snap);
      expect(parsed.audience, 'all');
    });
  });

  group('AnnouncementModel.visibleTo', () {
    AnnouncementModel withAudience(String audience) => AnnouncementModel(
          id: 'a',
          title: 't',
          body: 'b',
          authorId: 'c',
          authorName: 'Coach',
          createdAt: DateTime(2026),
          audience: audience,
        );

    test('coaches and admins see every announcement', () {
      for (final a in ['all', 'male', 'female']) {
        expect(withAudience(a).visibleTo(isCoach: true, gender: 'male'), isTrue);
      }
    });

    test('everyone audience is visible to any player', () {
      expect(withAudience('all').visibleTo(isCoach: false, gender: 'male'),
          isTrue);
      expect(withAudience('all').visibleTo(isCoach: false, gender: 'female'),
          isTrue);
    });

    test('players only see their own gender for a targeted announcement', () {
      final girls = withAudience('female');
      expect(girls.visibleTo(isCoach: false, gender: 'female'), isTrue);
      expect(girls.visibleTo(isCoach: false, gender: 'male'), isFalse);
    });
  });
}
