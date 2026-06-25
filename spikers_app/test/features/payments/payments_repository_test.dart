import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/features/payments/data/datasources/payments_remote_datasource.dart';
import 'package:spikers_app/features/payments/data/repositories/payments_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PaymentsRepositoryImpl repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = PaymentsRepositoryImpl(PaymentsRemoteDataSource(db));
  });

  Future<void> seedRecord(String uid, String status, DateTime changedAt,
      {String by = 'Coach'}) async {
    await db.collection('users').doc(uid).collection('payments').add({
      'status': status,
      'changedAt': Timestamp.fromDate(changedAt),
      'changedBy': 'c1',
      'changedByName': by,
    });
  }

  group('watchHistory', () {
    test('returns records newest-first and maps fields', () async {
      await seedRecord('p1', 'unpaid', DateTime(2026, 1, 1), by: 'Coach A');
      await seedRecord('p1', 'paid', DateTime(2026, 3, 1), by: 'Coach B');

      final records = await repo.watchHistory('p1').first;

      expect(records.length, 2);
      // Newest (March) first.
      expect(records.first.isPaid, isTrue);
      expect(records.first.changedByName, 'Coach B');
      expect(records.last.isPaid, isFalse);
      expect(records.last.changedByName, 'Coach A');
    });

    test('returns empty list when the user has no payment records', () async {
      final records = await repo.watchHistory('nobody').first;
      expect(records, isEmpty);
    });
  });
}
