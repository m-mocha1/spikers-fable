import 'package:cloud_firestore/cloud_firestore.dart';

/// One entry in a user's payment audit log (users/{uid}/payments/{autoId}),
/// written by a coach each time they adjust the user's membership.
///
/// Three shapes, keyed off the stored `status`: a renewal (`paid`), a
/// deactivation (`unpaid`), and days taken back off a still-running
/// membership (`adjusted`). Reductions carry their own status so the
/// "last paid" lookup, which queries `status == 'paid'`, doesn't mistake one
/// for a payment.
class PaymentRecord {
  final String id;

  /// True when this entry recorded the user as paid (status == 'paid').
  final bool isPaid;

  /// True when this entry took days back off a membership that stayed active
  /// (status == 'adjusted'). A reduction that ended the membership outright
  /// is stored as a plain deactivation instead.
  final bool isReduction;

  final DateTime changedAt;

  /// Display name of the coach who made the change.
  final String changedByName;

  /// Days this entry moved the expiry by — negative on a reduction — and the
  /// expiry that resulted. Null on deactivations and on records written before
  /// coaches could choose the length; the history row omits the detail line
  /// for those.
  final int? days;
  final DateTime? until;

  const PaymentRecord({
    required this.id,
    required this.isPaid,
    required this.changedAt,
    required this.changedByName,
    this.isReduction = false,
    this.days,
    this.until,
  });

  factory PaymentRecord.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final status = (d['status'] ?? '') as String;
    return PaymentRecord(
      id: doc.id,
      isPaid: status == 'paid',
      isReduction: status == 'adjusted',
      changedAt:
          (d['changedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      changedByName: (d['changedByName'] ?? '') as String,
      days: (d['days'] as num?)?.toInt(),
      until: (d['paidUntil'] as Timestamp?)?.toDate(),
    );
  }
}
