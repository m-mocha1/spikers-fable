import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import '../core/constants/app_assets.dart';
import '../models/session_model.dart';
import 'auth_controller.dart';

class SessionController extends GetxController {
  final _db = FirebaseFirestore.instance;
  final _fns = FirebaseFunctions.instanceFor(region: 'europe-west1');
  final _auth = Get.find<AuthController>();
  final _random = Random();

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

    // Firestore rules require email_verified == true to read sessions.
    // Skip the snapshot listener for unverified users so we don't hit
    // PERMISSION_DENIED. (Splash/signIn already route them away from /home,
    // but the permanent SessionController can re-fire on auth changes.)
    if (!_auth.isEmailVerified) {
      sessions.value = [];
      hasError.value = false;
      isLoading.value = false;
      return;
    }

    if (!user.isCoach && !user.isPaid) {
      sessions.value = [];
      hasError.value = false;
      isLoading.value = false;
      return;
    }

    Query<Map<String, dynamic>> query = _db
        .collection('sessions')
        .where('endTime', isGreaterThan: Timestamp.fromDate(DateTime.now()));

    if (!user.isCoach) {
      query = query.where('gender', whereIn: [user.gender, 'mixed']);
    }

    query = query.orderBy('endTime').orderBy('startTime');

    _sub = query.snapshots().listen((snapshot) {
      final now = DateTime.now();
      var all = snapshot.docs
          .map(SessionModel.fromDoc)
          .where((s) => s.endTime.isAfter(now))
          .toList();

      if (!user.isCoach) {
        final age = user.age;
        all = all.where((s) => age >= s.minAge && age <= s.maxAge).toList();
      }

      all.sort((a, b) => a.startTime.compareTo(b.startTime));

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
      final payload = session.toMap();
      payload['designIndex'] = _random.nextInt(AppAssets.cardDesigns.length);
      await _db.collection('sessions').add(payload);
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
      final res = await _fns
          .httpsCallable('joinSession')
          .call({'sessionId': sessionId});
      final status = (res.data?['status'] as String?) ?? '';
      if (status == 'waitlisted') {
        Get.snackbar('', 'waitlistedSnack'.tr,
            snackPosition: SnackPosition.BOTTOM);
      }
      // 'joined' and 'already_*' stay silent — the live snapshot will
      // update the UI and a snackbar would be noise.
    } on FirebaseFunctionsException catch (e) {
      Get.snackbar('', _mapJoinError(e), snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('', 'unknownError'.tr, snackPosition: SnackPosition.BOTTOM);
    } finally {
      await Future.delayed(_actionCooldown);
      isJoining.value = false;
    }
  }

  String _mapJoinError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'failed-precondition':
        return 'sessionFull'.tr;
      case 'not-found':
        return 'sessionMissing'.tr;
      case 'unauthenticated':
        return 'notSignedIn'.tr;
      default:
        // Surface the raw code during early-stage testing so the next
        // unexpected failure is diagnosable. Tighten once stable.
        return '${'unknownError'.tr} (${e.code})';
    }
  }

  Future<String?> updateSessionCapacity(
    String sessionId, {
    int? newMaxPlayers,
    int? newWaitlistSize,
  }) async {
    try {
      await _fns.httpsCallable('updateSessionCapacity').call({
        'sessionId': sessionId,
        'newMaxPlayers': ?newMaxPlayers,
        'newWaitlistSize': ?newWaitlistSize,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
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
      await _fns.httpsCallable('leaveSession').call({'sessionId': sessionId});
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
      await _fns.httpsCallable('markAttended').call({
        'sessionId': sessionId,
        'userId': userId,
        'attended': attended,
      });
    } catch (_) {
      Get.snackbar('', 'unknownError'.tr, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> sendMessage(String sessionId, String text) async {
    final user = _auth.currentUser.value;
    if (user == null) return;
    await _db
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .add({
      'senderId': user.uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelSession(String sessionId) async {
    if (isCancelling.value) return;
    isCancelling.value = true;
    try {
      await _fns.httpsCallable('cancelSession').call({'sessionId': sessionId});
      // Success navigation + snackbar are driven by the session-detail
      // snapshot listener (!doc.exists branch) so they fire exactly once,
      // regardless of which path observes the delete first.
    } on FirebaseFunctionsException catch (e) {
      Get.snackbar('', _mapCancelError(e), snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('', 'unknownError'.tr, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isCancelling.value = false;
    }
  }

  String _mapCancelError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'notYourSession'.tr;
      case 'not-found':
        return 'sessionMissing'.tr;
      case 'unauthenticated':
        return 'notSignedIn'.tr;
      default:
        return '${'unknownError'.tr} (${e.code})';
    }
  }
}
