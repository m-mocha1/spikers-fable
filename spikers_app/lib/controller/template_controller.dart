import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../core/firebase/firebase_providers.dart' show kFunctionsRegion;
import '../features/sessions/data/datasources/sessions_remote_datasource.dart';
import '../features/sessions/data/repositories/templates_repository_impl.dart';
import '../models/session_template_model.dart';
import 'auth_controller.dart';

/// MIGRATION SHIM — GetX facade over the templates repository.
class TemplateController extends GetxController {
  final _auth = Get.find<AuthController>();
  late final _repo = TemplatesRepositoryImpl(SessionsRemoteDataSource(
    FirebaseFirestore.instance,
    FirebaseFunctions.instanceFor(region: kFunctionsRegion),
  ));

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
    _sub = _repo.watch(uid).listen(
          (list) => templates.value = list,
          onError: (e) {
            debugPrint('TemplateController: templates listener error — $e');
          },
        );
  }

  Future<void> save(SessionTemplate template) async {
    final uid = _auth.currentUser.value?.uid;
    if (uid == null) return;
    await _repo.save(uid, template);
  }

  Future<void> delete(String templateId) async {
    final uid = _auth.currentUser.value?.uid;
    if (uid == null) return;
    await _repo.delete(uid, templateId);
  }
}
