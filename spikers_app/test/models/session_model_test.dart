import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<DocumentSnapshot> writeAndRead(Map<String, dynamic> data) async {
    final ref = db.collection('sessions').doc('s1');
    await ref.set(data);
    return ref.get();
  }

  SessionModel make({
    DateTime? start,
    DateTime? end,
    int maxPlayers = 10,
    List<String> attendeeIds = const [],
    int waitlistSize = 0,
    List<String> waitlistIds = const [],
  }) =>
      SessionModel(
        id: 's1',
        title: 'Evening practice',
        location: 'Main hall',
        gender: 'mixed',
        minAge: 16,
        maxAge: 40,
        startTime: start ?? DateTime(2026, 6, 1, 18),
        endTime: end ?? DateTime(2026, 6, 1, 20),
        maxPlayers: maxPlayers,
        coachId: 'c1',
        attendeeIds: attendeeIds,
        waitlistSize: waitlistSize,
        waitlistIds: waitlistIds,
        createdAt: DateTime(2026, 5, 1),
      );

  group('SessionModel', () {
    test('round-trips through toMap/fromDoc', () async {
      final session = make(
        attendeeIds: ['a', 'b'],
        waitlistSize: 3,
        waitlistIds: ['c'],
      );
      final snap = await writeAndRead(session.toMap());
      final parsed = SessionModel.fromDoc(snap);

      expect(parsed.id, 's1');
      expect(parsed.title, session.title);
      expect(parsed.location, session.location);
      expect(parsed.gender, 'mixed');
      expect(parsed.minAge, 16);
      expect(parsed.maxAge, 40);
      expect(parsed.startTime, session.startTime);
      expect(parsed.endTime, session.endTime);
      expect(parsed.maxPlayers, 10);
      expect(parsed.coachId, 'c1');
      expect(parsed.attendeeIds, ['a', 'b']);
      expect(parsed.waitlistSize, 3);
      expect(parsed.waitlistIds, ['c']);
      expect(parsed.notified, false);
      expect(parsed.designIndex, 0);
    });

    test('fromDoc defaults missing optional fields', () async {
      final snap = await writeAndRead({
        'startTime': Timestamp.fromDate(DateTime(2026, 6, 1, 18)),
        'endTime': Timestamp.fromDate(DateTime(2026, 6, 1, 20)),
        'createdAt': Timestamp.fromDate(DateTime(2026, 5, 1)),
      });
      final parsed = SessionModel.fromDoc(snap);
      expect(parsed.title, '');
      expect(parsed.gender, 'mixed');
      expect(parsed.minAge, 0);
      expect(parsed.maxAge, 99);
      expect(parsed.maxPlayers, 10);
      expect(parsed.attendeeIds, isEmpty);
      expect(parsed.waitlistIds, isEmpty);
    });

    test('capacity getters', () {
      final notFull = make(maxPlayers: 2, attendeeIds: ['a']);
      expect(notFull.isFull, isFalse);
      expect(notFull.spotsLeft, 1);
      expect(notFull.isJoinedBy('a'), isTrue);
      expect(notFull.isJoinedBy('z'), isFalse);

      final full = make(maxPlayers: 2, attendeeIds: ['a', 'b']);
      expect(full.isFull, isTrue);
      expect(full.spotsLeft, 0);
    });

    test('waitlist getters', () {
      final none = make();
      expect(none.hasWaitlist, isFalse);

      final wl = make(waitlistSize: 2, waitlistIds: ['x']);
      expect(wl.hasWaitlist, isTrue);
      expect(wl.isWaitlistFull, isFalse);
      expect(wl.waitlistSpotsLeft, 1);
      expect(wl.isWaitlistedBy('x'), isTrue);

      final wlFull = make(waitlistSize: 1, waitlistIds: ['x']);
      expect(wlFull.isWaitlistFull, isTrue);
    });

    test('time-state getters agree on a single now', () {
      final past = make(
        start: DateTime.now().subtract(const Duration(hours: 3)),
        end: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(past.isExpired, isTrue);
      expect(past.isOngoing, isFalse);
      expect(past.isUpcoming, isFalse);

      final ongoing = make(
        start: DateTime.now().subtract(const Duration(hours: 1)),
        end: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(ongoing.isOngoing, isTrue);
      expect(ongoing.isExpired, isFalse);

      final upcoming = make(
        start: DateTime.now().add(const Duration(hours: 1)),
        end: DateTime.now().add(const Duration(hours: 3)),
      );
      expect(upcoming.isUpcoming, isTrue);
      expect(upcoming.isOngoing, isFalse);
    });
  });
}
