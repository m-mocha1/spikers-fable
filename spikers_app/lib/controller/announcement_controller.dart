import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'auth_controller.dart';

class AnnouncementController extends GetxController {
  final _db = FirebaseFirestore.instance;
  final Rxn<DateTime> latestAt = Rxn<DateTime>();
  StreamSubscription? _latestSub;

  @override
  void onInit() {
    super.onInit();
    _listenLatest();
  }

  @override
  void onClose() {
    _latestSub?.cancel();
    super.onClose();
  }

  void _listenLatest() {
    _latestSub?.cancel();
    _latestSub = _db
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty) {
        latestAt.value = null;
        return;
      }
      latestAt.value =
          (snap.docs.first.data()['createdAt'] as Timestamp?)?.toDate();
    }, onError: (e) {
      debugPrint('AnnouncementController: latest listener error — $e');
    });
  }

  bool get hasUnread {
    final latest = latestAt.value;
    if (latest == null) return false;
    final user = Get.find<AuthController>().currentUser.value;
    final seen = user?.lastSeenAnnouncementsAt;
    return seen == null || latest.isAfter(seen);
  }

  Future<void> markRead() async {
    if (!hasUnread) return;
    final user = Get.find<AuthController>().currentUser.value;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'lastSeenAnnouncementsAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> create({
    required String title,
    required String body,
  }) async {
    final user = Get.find<AuthController>().currentUser.value;
    if (user == null) return;
    await _db.collection('announcements').add({
      'title': title,
      'body': body,
      'authorId': user.uid,
      'authorName': user.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> edit({
    required String id,
    required String title,
    required String body,
  }) async {
    await _db.collection('announcements').doc(id).update({
      'title': title,
      'body': body,
    });
  }

  Future<void> delete(String id) async {
    await _db.collection('announcements').doc(id).delete();
  }
}
