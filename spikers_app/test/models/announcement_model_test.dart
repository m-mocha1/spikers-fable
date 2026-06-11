import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/models/announcement_model.dart';

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
        'createdAt': Timestamp.fromDate(created),
      });
      final parsed = AnnouncementModel.fromDoc(snap);
      expect(parsed.id, 'a1');
      expect(parsed.title, 'Training moved');
      expect(parsed.body, 'We start at 19:00 this week.');
      expect(parsed.authorId, 'coach1');
      expect(parsed.authorName, 'Coach Dana');
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
  });
}
