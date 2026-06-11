import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';

import '../core/firebase/firebase_providers.dart' show kFunctionsRegion;
import '../features/sessions/data/datasources/sessions_remote_datasource.dart';
import '../features/sessions/data/repositories/session_chat_repository_impl.dart';
import '../features/sessions/data/repositories/sessions_repository_impl.dart';
import '../features/sessions/domain/repositories/sessions_repository.dart';
import '../models/session_model.dart';
import 'auth_controller.dart';

/// MIGRATION SHIM — GetX facade over the sessions repository for the
/// not-yet-migrated session screens. No Firebase logic lives here anymore.
class SessionController extends GetxController {
  final _auth = Get.find<AuthController>();

  late final SessionsRemoteDataSource _ds = SessionsRemoteDataSource(
    FirebaseFirestore.instance,
    FirebaseFunctions.instanceFor(region: kFunctionsRegion),
  );
  late final SessionsRepository _repo = SessionsRepositoryImpl(_ds);
  late final _chat = SessionChatRepositoryImpl(_ds);

  final sessions = <SessionModel>[].obs;
  final isLoading = true.obs;
  final isJoining = false.obs;
  final isCancelling = false.obs;
  final hasError = false.obs;

  // Keeps the join/leave button disabled briefly after each action so users
  // can't rage-toggle and thrash other devices' attendee lists.
  static const _actionCooldown = Duration(seconds: 3);

  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    ever(_auth.currentUser, (_) => fetchSessions());
    fetchSessions();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void fetchSessions() {
    _sub?.cancel();
    isLoading.value = true;
    hasError.value = false;

    final user = _auth.currentUser.value;
    if (user == null) {
      isLoading.value = false;
      return;
    }

    _sub = _repo
        .watchUpcoming(user, emailVerified: _auth.isEmailVerified)
        .listen((all) {
      sessions.value = all;
      hasError.value = false;
      isLoading.value = false;
    }, onError: (_) {
      isLoading.value = false;
      hasError.value = true;
    });
  }

  Future<void> createSession(SessionModel session) async {
    try {
      await _repo.create(session);
      Get.back();
      Get.snackbar('', 'sessionCreated'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('', 'unknownError'.tr, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> joinSession(String sessionId) async {
    if (isJoining.value) return;
    isJoining.value = true;
    try {
      final result = await _repo.join(sessionId);
      if (result == JoinResult.waitlisted) {
        Get.snackbar('', 'waitlistedSnack'.tr,
            snackPosition: SnackPosition.BOTTOM);
      }
      // 'joined' and 'already_*' stay silent — the live snapshot will
      // update the UI and a snackbar would be noise.
    } on SessionActionException catch (e) {
      Get.snackbar('', _mapJoinError(e.code),
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('', 'unknownError'.tr, snackPosition: SnackPosition.BOTTOM);
    } finally {
      await Future.delayed(_actionCooldown);
      isJoining.value = false;
    }
  }

  String _mapJoinError(String code) {
    switch (code) {
      case 'failed-precondition':
        return 'sessionFull'.tr;
      case 'not-found':
        return 'sessionMissing'.tr;
      case 'unauthenticated':
        return 'notSignedIn'.tr;
      default:
        // Surface the raw code during early-stage testing so the next
        // unexpected failure is diagnosable. Tighten once stable.
        return '${'unknownError'.tr} ($code)';
    }
  }

  Future<String?> updateSessionCapacity(
    String sessionId, {
    int? newMaxPlayers,
    int? newWaitlistSize,
  }) async {
    try {
      await _repo.updateCapacity(sessionId,
          newMaxPlayers: newMaxPlayers, newWaitlistSize: newWaitlistSize);
      return null;
    } on SessionActionException catch (e) {
      switch (e.code) {
        case 'failed-precondition':
          return 'capacityMustNotDecrease'.tr;
        case 'permission-denied':
          return 'notYourSession'.tr;
        case 'invalid-argument':
          return 'nothingToUpdate'.tr;
        case 'not-found':
          return 'sessionMissing'.tr;
        case 'unauthenticated':
          return 'notSignedIn'.tr;
        default:
          return '${'unknownError'.tr} (${e.code})';
      }
    } catch (_) {
      return 'unknownError'.tr;
    }
  }

  Future<void> leaveSession(String sessionId) async {
    if (isJoining.value) return;
    isJoining.value = true;
    try {
      await _repo.leave(sessionId);
    } catch (_) {
      Get.snackbar('', 'unknownError'.tr, snackPosition: SnackPosition.BOTTOM);
    } finally {
      await Future.delayed(_actionCooldown);
      isJoining.value = false;
    }
  }

  Future<void> markAttended(
      String sessionId, String userId, bool attended) async {
    try {
      await _repo.markAttended(sessionId, userId, attended);
    } catch (_) {
      Get.snackbar('', 'unknownError'.tr, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> sendMessage(String sessionId, String text) async {
    final user = _auth.currentUser.value;
    if (user == null) return;
    await _chat.send(sessionId, senderId: user.uid, text: text);
  }

  Future<void> cancelSession(String sessionId) async {
    if (isCancelling.value) return;
    isCancelling.value = true;
    try {
      await _repo.cancel(sessionId);
      // Success navigation + snackbar are driven by the session-detail
      // snapshot listener (!doc.exists branch) so they fire exactly once,
      // regardless of which path observes the delete first.
    } on SessionActionException catch (e) {
      Get.snackbar('', _mapCancelError(e.code),
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('', 'unknownError'.tr, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isCancelling.value = false;
    }
  }

  String _mapCancelError(String code) {
    switch (code) {
      case 'permission-denied':
        return 'notYourSession'.tr;
      case 'not-found':
        return 'sessionMissing'.tr;
      case 'unauthenticated':
        return 'notSignedIn'.tr;
      default:
        return '${'unknownError'.tr} ($code)';
    }
  }
}
