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
}
