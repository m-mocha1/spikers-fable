import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/recurring_session_model.dart';
import 'auth_controller.dart';

class RecurringSessionController extends GetxController {
  final _db = FirebaseFirestore.instance;
  final _auth = Get.find<AuthController>();

  final recurringSessions = <RecurringSessionModel>[].obs;
  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    _listen();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _listen() {
    final uid = _auth.currentUser.value?.uid;
    if (uid == null) return;
    _sub = _db
        .collection('recurring_sessions')
        .where('coachId', isEqualTo: uid)
        .snapshots()
        .listen(
      (snap) {
        final list = <RecurringSessionModel>[];
        for (final d in snap.docs) {
          try {
            list.add(RecurringSessionModel.fromDoc(d));
          } catch (e) {
            debugPrint('recurring_sessions: skip ${d.id} — $e');
          }
        }
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        recurringSessions.value = list;
      },
      onError: (e) {
        debugPrint('recurring_sessions stream error: $e');
      },
    );
  }

  Future<void> create(RecurringSessionModel model) async {
    await _db.collection('recurring_sessions').add(model.toMap());
  }

  Future<void> edit(String id, Map<String, dynamic> data) async {
    await _db.collection('recurring_sessions').doc(id).update(data);
  }

  Future<void> toggleEnabled(String id, bool enabled) async {
    await _db
        .collection('recurring_sessions')
        .doc(id)
        .update({'enabled': enabled});
  }

  Future<void> delete(String id) async {
    await _db.collection('recurring_sessions').doc(id).delete();
  }
}
