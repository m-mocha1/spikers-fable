import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'auth_controller.dart';

class PaymentController extends GetxController {
  final _db = FirebaseFirestore.instance;
  final _auth = Get.find<AuthController>();

  static const _periodDays = 30;

  Future<bool> _isLifetimeMember(String playerUid) async {
    final snap = await _db.collection('users').doc(playerUid).get();
    return (snap.data()?['lifetimeMember'] ?? false) as bool;
  }

  Future<void> markPaid(String playerUid) async {
    final coach = _auth.currentUser.value;
    if (coach == null) return;
    if (await _isLifetimeMember(playerUid)) return;

    final now = DateTime.now();
    final until = now.add(const Duration(days: _periodDays));
    final userRef = _db.collection('users').doc(playerUid);
    final auditRef = userRef.collection('payments').doc();

    final batch = _db.batch();
    batch.update(userRef, {
      'paidUntil': Timestamp.fromDate(until),
      'paidAt': Timestamp.fromDate(now),
    });
    batch.set(auditRef, {
      'status': 'paid',
      'changedAt': Timestamp.fromDate(now),
      'changedBy': coach.uid,
      'changedByName': coach.name,
    });
    await batch.commit();
  }

  Future<void> markUnpaid(String playerUid) async {
    final coach = _auth.currentUser.value;
    if (coach == null) return;
    if (await _isLifetimeMember(playerUid)) return;

    final now = DateTime.now();
    final userRef = _db.collection('users').doc(playerUid);
    final auditRef = userRef.collection('payments').doc();

    final batch = _db.batch();
    batch.update(userRef, {
      'paidUntil': FieldValue.delete(),
      'paidAt': FieldValue.delete(),
    });
    batch.set(auditRef, {
      'status': 'unpaid',
      'changedAt': Timestamp.fromDate(now),
      'changedBy': coach.uid,
      'changedByName': coach.name,
    });
    await batch.commit();
  }
}
