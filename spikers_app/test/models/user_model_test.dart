import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  Future<DocumentSnapshot> writeAndRead(Map<String, dynamic> data) async {
    final ref = db.collection('users').doc('u1');
    await ref.set(data);
    return ref.get();
  }

  group('UserModel', () {
    test('round-trips through toMap/fromDoc', () async {
      final dob = DateTime(2000, 5, 17);
      final created = DateTime(2026, 1, 2, 3, 4);
      final paidUntil = DateTime(2026, 7, 1);
      final user = UserModel(
        uid: 'u1',
        name: 'Sami',
        gender: 'male',
        dateOfBirth: dob,
        role: 'player',
        createdAt: created,
        verifiedAt: created,
        paidUntil: paidUntil,
        paidAt: created,
        heightCm: 183,
        weightKg: 78,
        lastSeenAnnouncementsAt: created,
      );

      final snap = await writeAndRead(user.toMap());
      final parsed = UserModel.fromDoc(snap);

      expect(parsed.uid, 'u1');
      expect(parsed.name, 'Sami');
      expect(parsed.gender, 'male');
      expect(parsed.dateOfBirth, dob);
      expect(parsed.role, 'player');
      expect(parsed.createdAt, created);
      expect(parsed.verifiedAt, created);
      expect(parsed.paidUntil, paidUntil);
      expect(parsed.paidAt, created);
      expect(parsed.heightCm, 183);
      expect(parsed.weightKg, 78);
      expect(parsed.lastSeenAnnouncementsAt, created);
      expect(parsed.lifetimeMember, false);
      expect(parsed.injured, false);
    });

    test('toMap writes verifiedAt explicitly as null when unverified',
        () async {
      final user = UserModel(
        uid: 'u1',
        name: 'Sami',
        gender: 'male',
        dateOfBirth: DateTime(2000),
        role: 'player',
        createdAt: DateTime(2026),
      );
      // cleanupUnverifiedUsers queries `verifiedAt == null`, which only
      // matches a present null — never a missing field.
      expect(user.toMap().containsKey('verifiedAt'), isTrue);
      expect(user.toMap()['verifiedAt'], isNull);
    });

    test('fromDoc defaults missing optional fields', () async {
      final snap = await writeAndRead({
        'dateOfBirth': Timestamp.fromDate(DateTime(2001)),
        'createdAt': Timestamp.fromDate(DateTime(2026)),
      });
      final parsed = UserModel.fromDoc(snap);
      expect(parsed.name, '');
      expect(parsed.gender, isNull);
      expect(parsed.role, 'player');
      expect(parsed.photoUrl, isNull);
      expect(parsed.paidUntil, isNull);
      expect(parsed.lifetimeMember, false);
      expect(parsed.injured, false);
    });

    test('injured: defaults false, parses true; never written by toMap',
        () async {
      // Admin-set flag (Firebase console), so it must read back but stay out
      // of the client write path — same contract as lifetimeMember.
      final user = UserModel(
        uid: 'u1',
        name: 'Sami',
        role: 'player',
        createdAt: DateTime(2026),
      );
      expect(user.injured, false);
      expect(user.toMap().containsKey('injured'), isFalse);

      final parsed = UserModel.fromDoc(await writeAndRead({
        'name': 'Sami',
        'createdAt': Timestamp.fromDate(DateTime(2026)),
        'injured': true,
      }));
      expect(parsed.injured, true);
    });

    test('gender/DOB are optional: omitted from toMap and age is null',
        () async {
      final user = UserModel(
        uid: 'u1',
        name: 'No Profile',
        role: 'player',
        createdAt: DateTime(2026),
      );
      final map = user.toMap();
      expect(map.containsKey('gender'), isFalse);
      expect(map.containsKey('dateOfBirth'), isFalse);
      expect(user.age, isNull);

      final parsed = UserModel.fromDoc(await writeAndRead(map));
      expect(parsed.gender, isNull);
      expect(parsed.dateOfBirth, isNull);
      expect(parsed.age, isNull);
    });

    test('isPaid: lifetime member is paid regardless of paidUntil', () {
      final user = UserModel(
        uid: 'u1',
        name: '',
        gender: 'male',
        dateOfBirth: DateTime(2000),
        role: 'player',
        createdAt: DateTime(2026),
        lifetimeMember: true,
      );
      expect(user.isPaid, isTrue);
      expect(user.paymentDaysLeft, 0);
    });

    test('isPaid: future paidUntil is paid, past is not', () {
      UserModel withPaidUntil(DateTime? until) => UserModel(
            uid: 'u1',
            name: '',
            gender: 'male',
            dateOfBirth: DateTime(2000),
            role: 'player',
            createdAt: DateTime(2026),
            paidUntil: until,
          );
      expect(
          withPaidUntil(DateTime.now().add(const Duration(days: 3))).isPaid,
          isTrue);
      expect(
          withPaidUntil(DateTime.now().subtract(const Duration(days: 3)))
              .isPaid,
          isFalse);
      expect(withPaidUntil(null).isPaid, isFalse);
    });

    test('daysLeftUntil uses calendar days, never negative', () {
      final now = DateTime.now();
      // Expiring tomorrow at 00:01 still reads as 1 day left.
      final tomorrowEarly =
          DateTime(now.year, now.month, now.day).add(const Duration(days: 1, minutes: 1));
      expect(UserModel.daysLeftUntil(tomorrowEarly), 1);
      expect(UserModel.daysLeftUntil(now.subtract(const Duration(days: 5))), 0);
      expect(UserModel.daysLeftUntil(null), 0);
    });

    test('isCoach only for coach role', () {
      UserModel withRole(String role) => UserModel(
            uid: 'u1',
            name: '',
            gender: 'male',
            dateOfBirth: DateTime(2000),
            role: role,
            createdAt: DateTime(2026),
          );
      expect(withRole('coach').isCoach, isTrue);
      expect(withRole('player').isCoach, isFalse);
    });
  });
}
