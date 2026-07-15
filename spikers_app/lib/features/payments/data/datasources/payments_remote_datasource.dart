import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/payment_record.dart';

class PaymentsRemoteDataSource {
  final FirebaseFirestore _db;

  PaymentsRemoteDataSource(this._db);

  Stream<List<PaymentRecord>> watchHistory(String userId) => _db
      .collection('users')
      .doc(userId)
      .collection('payments')
      .orderBy('changedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(PaymentRecord.fromDoc).toList());

  /// Reads the audit log rather than users/{userId}.paidAt because markUnpaid
  /// deletes paidAt — the log is the only record of a payment that survives a
  /// later lapse. Needs the (status, changedAt desc) index on `payments`.
  Future<DateTime?> fetchLastPaidAt(String userId) async {
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('payments')
        .where('status', isEqualTo: 'paid')
        .orderBy('changedAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return (snap.docs.first.data()['changedAt'] as Timestamp?)?.toDate();
  }
}
