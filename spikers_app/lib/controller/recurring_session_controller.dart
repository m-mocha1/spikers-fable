import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../core/firebase/firebase_providers.dart' show kFunctionsRegion;
import '../features/sessions/data/datasources/sessions_remote_datasource.dart';
import '../features/sessions/data/repositories/recurring_sessions_repository_impl.dart';
import '../models/recurring_session_model.dart';
import 'auth_controller.dart';

/// MIGRATION SHIM — GetX facade over the recurring-sessions repository.
class RecurringSessionController extends GetxController {
  final _auth = Get.find<AuthController>();
  late final _repo =
      RecurringSessionsRepositoryImpl(SessionsRemoteDataSource(
    FirebaseFirestore.instance,
    FirebaseFunctions.instanceFor(region: kFunctionsRegion),
  ));

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
    _sub = _repo.watchForCoach(uid).listen(
          (list) => recurringSessions.value = list,
          onError: (e) {
            debugPrint('recurring_sessions stream error: $e');
          },
        );
  }

  Future<void> create(RecurringSessionModel model) => _repo.create(model);

  Future<void> edit(String id, Map<String, dynamic> data) =>
      _repo.edit(id, data);

  Future<void> toggleEnabled(String id, bool enabled) =>
      _repo.toggleEnabled(id, enabled);

  Future<void> delete(String id) => _repo.delete(id);
}
