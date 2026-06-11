import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/models/session_template_model.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<DocumentSnapshot> writeAndRead(Map<String, dynamic> data) async {
    final ref = db.collection('session_templates').doc('t1');
    await ref.set(data);
    return ref.get();
  }

  group('SessionTemplate', () {
    test('round-trips through toMap/fromDoc', () async {
      final created = DateTime(2026, 4, 5);
      final template = SessionTemplate(
        id: 't1',
        title: 'Beach setup',
        location: 'Beach court',
        gender: 'mixed',
        minAge: 18,
        maxAge: 45,
        maxPlayers: 8,
        waitlistSize: 2,
        createdAt: created,
      );
      final snap = await writeAndRead(template.toMap());
      final parsed = SessionTemplate.fromDoc(snap);

      expect(parsed.id, 't1');
      expect(parsed.title, 'Beach setup');
      expect(parsed.location, 'Beach court');
      expect(parsed.gender, 'mixed');
      expect(parsed.minAge, 18);
      expect(parsed.maxAge, 45);
      expect(parsed.maxPlayers, 8);
      expect(parsed.waitlistSize, 2);
      expect(parsed.createdAt, created);
    });

    test('empty doc parses with defaults instead of throwing', () async {
      // Regression for audit A5 — fromDoc used to bare-cast and throw on
      // partial docs, killing the whole template stream.
      final snap = await writeAndRead({});
      final parsed = SessionTemplate.fromDoc(snap);
      expect(parsed.title, '');
      expect(parsed.location, '');
      expect(parsed.gender, 'mixed');
      expect(parsed.minAge, 0);
      expect(parsed.maxAge, 99);
      expect(parsed.maxPlayers, 10);
      expect(parsed.waitlistSize, 0);
      expect(parsed.createdAt, isA<DateTime>());
    });
  });
}
