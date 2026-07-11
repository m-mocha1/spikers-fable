import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/features/sessions/domain/entities/recurring_session_model.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<DocumentSnapshot> writeAndRead(Map<String, dynamic> data) async {
    final ref = db.collection('recurring_sessions').doc('r1');
    await ref.set(data);
    return ref.get();
  }

  group('RecurringSessionModel', () {
    test('round-trips through toMap/fromDoc', () async {
      final created = DateTime(2026, 2, 3);
      final model = RecurringSessionModel(
        id: 'r1',
        coachId: 'c1',
        title: 'Tuesday drills',
        location: 'Court 2',
        gender: 'female',
        minAge: 14,
        maxAge: 30,
        maxPlayers: 14,
        waitlistSize: 4,
        coachIds: ['co1', 'co2'],
        memberIds: ['m1'],
        recurrenceDays: [2, 4],
        startHour: 18,
        startMinute: 30,
        endHour: 20,
        endMinute: 0,
        createdAt: created,
      );
      final snap = await writeAndRead(model.toMap());
      final parsed = RecurringSessionModel.fromDoc(snap);

      expect(parsed.id, 'r1');
      expect(parsed.coachId, 'c1');
      expect(parsed.title, 'Tuesday drills');
      expect(parsed.location, 'Court 2');
      expect(parsed.gender, 'female');
      expect(parsed.minAge, 14);
      expect(parsed.maxAge, 30);
      expect(parsed.maxPlayers, 14);
      expect(parsed.waitlistSize, 4);
      expect(parsed.coachIds, ['co1', 'co2']);
      expect(parsed.memberIds, ['m1']);
      expect(parsed.recurrenceDays, [2, 4]);
      expect(parsed.startHour, 18);
      expect(parsed.startMinute, 30);
      expect(parsed.endHour, 20);
      expect(parsed.endMinute, 0);
      expect(parsed.enabled, isTrue);
      expect(parsed.createdAt, created);
      // toMap intentionally omits lastCreatedDate — only the backend's
      // recurring-session generator writes it.
      expect(parsed.lastCreatedDate, isNull);
    });

    test('empty doc parses with defaults instead of throwing', () async {
      final snap = await writeAndRead({});
      final parsed = RecurringSessionModel.fromDoc(snap);
      expect(parsed.gender, 'mixed');
      expect(parsed.minAge, 16);
      expect(parsed.maxAge, 40);
      expect(parsed.maxPlayers, 12);
      expect(parsed.coachIds, isEmpty);
      expect(parsed.memberIds, isEmpty);
      expect(parsed.recurrenceDays, isEmpty);
      expect(parsed.enabled, isTrue);
      expect(parsed.createdAt, isA<DateTime>());
    });

    test('non-string lastCreatedDate is treated as null', () async {
      final snap = await writeAndRead({'lastCreatedDate': 12345});
      expect(RecurringSessionModel.fromDoc(snap).lastCreatedDate, isNull);
    });
  });
}
