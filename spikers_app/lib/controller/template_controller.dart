import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/session_template_model.dart';
import 'auth_controller.dart';

class TemplateController extends GetxController {
  final _db = FirebaseFirestore.instance;
  final _auth = Get.find<AuthController>();

  final templates = <SessionTemplate>[].obs;
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
        .collection('users')
        .doc(uid)
        .collection('templates')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snap) => templates.value =
              snap.docs.map(SessionTemplate.fromDoc).toList(),
          onError: (e) {
            debugPrint('TemplateController: templates listener error — $e');
          },
        );
  }

  Future<void> save(SessionTemplate template) async {
    final uid = _auth.currentUser.value?.uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('templates')
        .add(template.toMap());
  }

  Future<void> delete(String templateId) async {
    final uid = _auth.currentUser.value?.uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('templates')
        .doc(templateId)
        .delete();
  }
}
