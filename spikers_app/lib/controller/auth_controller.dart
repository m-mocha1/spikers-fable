import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import 'announcement_controller.dart';
import 'notification_controller.dart';
import 'payment_controller.dart';
import 'recurring_session_controller.dart';
import 'session_controller.dart';
import 'template_controller.dart';

// FCM token storage contract:
// The device's FCM token lives at `users/{uid}/private/fcm` (subcollection),
// NOT on the user document. Writes to users/{uid} fan out to PlayersTab and
// AuthController._listenToUser listeners; token refreshes are noise to both.
// Cloud Functions that send notifications (onSessionCreated, cancelSession)
// must read the token from this subcollection path.

class AuthController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final Rxn<UserModel> currentUser = Rxn<UserModel>();
  final isLoading = false.obs;

  bool get isCoach => currentUser.value?.isCoach ?? false;
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;
  String get currentEmail => _auth.currentUser?.email ?? '';
  bool get isSignedIn => _auth.currentUser != null;

  final _readyCompleter = Completer<void>();
  StreamSubscription? _userSub;
  StreamSubscription? _authStateSub;
  StreamSubscription? _tokenRefreshSub;

  static const _kEmail = '_se';
  static const _kPass = '_sp';

  /// Splash screen awaits this before navigating.
  Future<void> waitForAuth() => _readyCompleter.future;

  @override
  void onInit() {
    super.onInit();
    _initAuth();
  }

  Future<void> _initAuth() async {
    if (_auth.currentUser == null) {
      await _tryRestoreSession();
    }

    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _listenToUser(user.uid);
        _updateFcmToken(user.uid);
      } catch (e) {
        debugPrint('auth: initial user listen/FCM setup failed — $e');
      }
    }

    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    _authStateSub =
        _auth.authStateChanges().skip(1).listen(_onAuthStateChanged);
  }

  Future<bool> _tryRestoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_kEmail);
      final encoded = prefs.getString(_kPass);
      if (email == null || encoded == null) return false;
      final password = utf8.decode(base64.decode(encoded));
      await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return _auth.currentUser != null;
    } catch (_) {
      await _clearCredentials();
      return false;
    }
  }

  Future<void> _saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEmail, email);
    await prefs.setString(_kPass, base64.encode(utf8.encode(password)));
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEmail);
    await prefs.remove(_kPass);
    await prefs.remove('debug_last_uid');
  }

  @override
  void onClose() {
    _userSub?.cancel();
    _authStateSub?.cancel();
    _tokenRefreshSub?.cancel();
    super.onClose();
  }

  Future<void> _onAuthStateChanged(User? user) async {
    try {
      if (user == null) {
        await _userSub?.cancel();
        _userSub = null;
        currentUser.value = null;
      } else {
        await _listenToUser(user.uid);
        _updateFcmToken(user.uid);
      }
    } catch (_) {
      if (_auth.currentUser == null) {
        currentUser.value = null;
      }
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> _listenToUser(String uid) async {
    await _userSub?.cancel();
    final firstSnap = Completer<void>();
    _userSub = _db.collection('users').doc(uid).snapshots().listen(
      (doc) {
        currentUser.value = doc.exists ? UserModel.fromDoc(doc) : null;

        // Heal verifiedAt if it's null on the server side (verified on
        // another device, or verify-screen write was dropped). Skip
        // snapshots with pending writes — Firestore shows
        // FieldValue.serverTimestamp() as null locally until the server
        // confirms, and that would re-trigger this heal in a loop.
        if (!doc.metadata.hasPendingWrites &&
            doc.exists &&
            _auth.currentUser?.emailVerified == true &&
            (doc.data() ?? const {})['verifiedAt'] == null) {
          doc.reference
              .update({'verifiedAt': FieldValue.serverTimestamp()})
              .catchError((_) {});
        }

        if (!firstSnap.isCompleted) firstSnap.complete();
      },
      onError: (e) {
        if (!firstSnap.isCompleted) firstSnap.completeError(e);
      },
    );
    await firstSnap.future;
  }

  Future<void> _updateFcmToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _writeTokenIfChanged(uid, token);
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _writeTokenIfChanged(uid, t);
      });
    } catch (e) {
      debugPrint('auth: FCM token update failed — $e');
    }
  }

  Future<void> _writeTokenIfChanged(String uid, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'fcm_last_token_$uid';
      if (prefs.getString(key) == token) return;
      await _db
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('fcm')
          .set(
        {
          'token': token,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await prefs.setString(key, token);
    } catch (e) {
      debugPrint('auth: FCM token write failed — $e');
    }
  }

  Future<void> signIn(String email, String password) async {
    isLoading.value = true;
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _saveCredentials(email.trim(), password);
      await _readyCompleter.future;
      Get.offAllNamed(
          isEmailVerified ? Routes.home : Routes.verifyEmail);
    } on FirebaseAuthException catch (e) {
      _showError(_authError(e.code));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendVerificationEmail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (_) {
      _showError('unknownError'.tr);
    }
  }

  Future<bool> reloadAndCheckVerified() async {
    try {
      await _auth.currentUser?.reload();
      final verified = _auth.currentUser?.emailVerified ?? false;
      if (verified) {
        // CRITICAL: reload() refreshes user fields but NOT the ID token.
        // Firestore authenticates via the ID token, which still carries the
        // stale `email_verified: false` claim until forced. Without this,
        // the isVerified() rule rejects queries immediately after verify.
        await _auth.currentUser?.getIdToken(true);
      }
      return verified;
    } catch (_) {
      return false;
    }
  }

  /// Sends a verification email to [newEmail]. The Auth user's email field
  /// does not change until the new link is clicked. Returns null on success
  /// or a localized error string on failure.
  ///
  /// Also resets the cleanup clock on the Firestore profile by bumping
  /// `createdAt` to now, so cleanupUnverifiedUsers won't sweep this user
  /// during the new verification window.
  Future<String?> updatePendingEmail(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'unknownError'.tr;
      await user.verifyBeforeUpdateEmail(newEmail.trim());
      try {
        await _db.collection('users').doc(user.uid).update({
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Non-fatal — if this fails the user might be cleaned up early.
      }
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          return 'invalidEmail'.tr;
        case 'email-already-in-use':
          return 'emailAlreadyInUse'.tr;
        case 'requires-recent-login':
          return 'sessionExpired'.tr;
        default:
          return 'unknownError'.tr;
      }
    } catch (_) {
      return 'unknownError'.tr;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String gender,
    required DateTime dateOfBirth,
    required int heightCm,
    required int weightKg,
    required String role,
    required String coachKey,
    XFile? photoFile,
  }) async {
    isLoading.value = true;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await _saveCredentials(email.trim(), password);

      String? photoUrl;
      if (photoFile != null) {
        final ref = FirebaseStorage.instance
            .ref('profilePhotos/${cred.user!.uid}.jpg');
        await ref.putFile(File(photoFile.path));
        photoUrl = await ref.getDownloadURL();
      }

      final now = DateTime.now();

      // Firestore rules require role == 'player' at create. Coaches are
      // promoted server-side by validateCoachKey below.
      final user = UserModel(
        uid: cred.user!.uid,
        name: name.trim(),
        gender: gender,
        dateOfBirth: dateOfBirth,
        role: 'player',
        photoUrl: photoUrl,
        createdAt: now,
        paidUntil: null,
        paidAt: null,
        heightCm: heightCm,
        weightKg: weightKg,
      );
      await _db.collection('users').doc(user.uid).set({
        ...user.toMap(),
        'photoUrl': ?photoUrl,
      });
      currentUser.value = user;

      if (role == 'coach') {
        final promoted = await _validateCoachKey(coachKey);
        if (promoted == false) {
          _showError('invalidCoachKey'.tr);
          // User stays as a player. They keep the account and can retry
          // coach promotion later from settings (or re-register).
        }
        // promoted == null means a network error; the helper already
        // surfaced its own snackbar. Either way, continue to verify-email.
      }

      try {
        await cred.user?.sendEmailVerification();
      } catch (_) {
        // Non-fatal — user can resend from the verify screen.
      }

      Get.offAllNamed(Routes.verifyEmail);
    } on FirebaseAuthException catch (e) {
      _showError(_authError(e.code));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    isLoading.value = true;
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      Get.back();
      Get.snackbar('', 'sendResetEmail'.tr,
          snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
    } on FirebaseAuthException catch (e) {
      _showError(_authError(e.code));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateProfilePhoto(XFile image) async {
    final uid = currentUser.value?.uid;
    if (uid == null) return;
    isLoading.value = true;
    try {
      final ref = FirebaseStorage.instance.ref('profilePhotos/$uid.jpg');
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();
      await _db.collection('users').doc(uid).update({'photoUrl': url});
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) currentUser.value = UserModel.fromDoc(doc);
      Get.snackbar('', 'photoUpdated'.tr, snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('', 'unknownError'.tr, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateBodyMetrics({
    required int heightCm,
    required int weightKg,
  }) async {
    final uid = currentUser.value?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'heightCm': heightCm,
      'weightKg': weightKg,
    });
  }

  Future<void> signOut() async {
    await _clearCredentials();
    await _auth.signOut();
    currentUser.value = null;
    // Tear down permanent domain controllers so their Firestore listeners
    // and cached state don't survive into the next user's session. They
    // rebuild on the next /home navigation via the route binding.
    if (Get.isRegistered<SessionController>()) {
      Get.delete<SessionController>(force: true);
    }
    if (Get.isRegistered<TemplateController>()) {
      Get.delete<TemplateController>(force: true);
    }
    if (Get.isRegistered<PaymentController>()) {
      Get.delete<PaymentController>(force: true);
    }
    if (Get.isRegistered<NotificationController>()) {
      Get.delete<NotificationController>(force: true);
    }
    if (Get.isRegistered<AnnouncementController>()) {
      Get.delete<AnnouncementController>(force: true);
    }
    if (Get.isRegistered<RecurringSessionController>()) {
      Get.delete<RecurringSessionController>(force: true);
    }
    Get.offAllNamed(Routes.login);
  }

  Future<bool?> _validateCoachKey(String input) async {
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('validateCoachKey')
          .call({'key': input});
      return (result.data?['valid'] ?? false) as bool;
    } catch (_) {
      _showError('networkError'.tr);
      return null;
    }
  }

  void _showError(String msg) {
    Get.snackbar('', msg,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3));
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'wrongPassword'.tr;
      case 'email-already-in-use':
        return 'emailAlreadyInUse'.tr;
      case 'weak-password':
        return 'passwordTooShort'.tr;
      case 'too-many-requests':
        return 'tooManyRequests'.tr;
      case 'user-disabled':
        return 'userDisabled'.tr;
      case 'network-request-failed':
        return 'networkError'.tr;
      default:
        return 'unknownError'.tr;
    }
  }
}
