import 'package:cloud_firestore/cloud_firestore.dart';

/// One entry in a user's payment audit log (users/{uid}/payments/{autoId}),
/// written by a coach each time they mark the user paid or unpaid.
class PaymentRecord {
  final String id;

  /// True when this entry recorded the user as paid (status == 'paid').
  final bool isPaid;
  final DateTime changedAt;

  /// Display name of the coach who made the change.
  final String changedByName;

  const PaymentRecord({
    required this.id,
    required this.isPaid,
    required this.changedAt,
    required this.changedByName,
  });

  factory PaymentRecord.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return PaymentRecord(
      id: doc.id,
      isPaid: (d['status'] ?? '') == 'paid',
      changedAt:
          (d['changedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      changedByName: (d['changedByName'] ?? '') as String,
    );
  }
}
