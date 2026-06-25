import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/firebase/firebase_providers.dart' show kFunctionsRegion;
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/credential_store.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final CredentialStore _credentials;
  final FirebaseMessaging? _messaging;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required CredentialStore credentials,
    FirebaseMessaging? messaging,
  })  : _remote = remote,
        _credentials = credentials,
        _messaging = messaging;

  /// Production instance shared by the Riverpod providers and the temporary
  /// GetX AuthController shim. The shim dies with the last GetX consumers;
  /// until then both worlds must observe the same session.
  static AuthRepositoryImpl? _instance;
  static AuthRepositoryImpl get instance => _instance ??= AuthRepositoryImpl(
        remote: AuthRemoteDataSource(
          auth: FirebaseAuth.instance,
          db: FirebaseFirestore.instance,
          storage: FirebaseStorage.instance,
          functions: FirebaseFunctions.instanceFor(region: kFunctionsRegion),
        ),
        credentials: SecureCredentialStore(),
        messaging: FirebaseMessaging.instance,
      )..init();

  final _readyCompleter = Completer<void>();
  final _userController = StreamController<UserModel?>.broadcast();
  UserModel? _lastUser;
  bool _hasEmitted = false;
  bool _initStarted = false;

  StreamSubscription? _userSub;
  StreamSubscription? _authStateSub;
  StreamSubscription? _tokenRefreshSub;

  @override
  Future<void> get ready => _readyCompleter.future;

  @override
  UserModel? get currentUserNow => _lastUser;

  @override
  bool get isSignedIn => _remote.auth.currentUser != null;

  @override
  bool get isEmailVerified => _remote.auth.currentUser?.emailVerified ?? false;

  @override
  String get currentEmail => _remote.auth.currentUser?.email ?? '';

  @override
  Stream<UserModel?> watchCurrentUser() async* {
    if (_hasEmitted) yield _lastUser;
    yield* _userController.stream;
  }

  void _emit(UserModel? user) {
    _lastUser = user;
    _hasEmitted = true;
    _userController.add(user);
  }

  /// Restores the session and starts the auth-state pipeline. Idempotent.
  Future<void> init() async {
    if (_initStarted) return;
    _initStarted = true;

    if (_remote.auth.currentUser == null) {
      await _tryRestoreSession();
    }

    final user = _remote.auth.currentUser;
    if (user != null) {
      try {
        await _listenToUser(user.uid);
        await _refreshTokenIfVerified();
        _updateFcmToken(user.uid);
      } catch (e) {
        debugPrint('auth: initial user listen/FCM setup failed — $e');
      }
    }

    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    _authStateSub =
        _remote.auth.authStateChanges().skip(1).listen(_onAuthStateChanged);
  }

  Future<bool> _tryRestoreSession() async {
    try {
      final creds = await _credentials.read();
      if (creds == null) return false;
      await _remote.signIn(creds.email, creds.password);
      return _remote.auth.currentUser != null;
    } catch (_) {
      await _credentials.clear();
      return false;
    }
  }

  Future<void> _onAuthStateChanged(User? user) async {
    try {
      if (user == null) {
        await _userSub?.cancel();
        _userSub = null;
        _emit(null);
      } else {
        await _listenToUser(user.uid);
        await _refreshTokenIfVerified();
        _updateFcmToken(user.uid);
      }
    } catch (_) {
      if (_remote.auth.currentUser == null) _emit(null);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> _listenToUser(String uid) async {
    await _userSub?.cancel();
    final firstSnap = Completer<void>();
    _userSub = _remote.userDocStream(uid).listen(
      (doc) {
        _emit(doc.exists ? UserModel.fromDoc(doc) : null);

        // Heal verifiedAt if it's null on the server side (verified on
        // another device, or verify-screen write was dropped). Skip
        // snapshots with pending writes — Firestore shows
        // FieldValue.serverTimestamp() as null locally until the server
        // confirms, and that would re-trigger this heal in a loop.
        if (!doc.metadata.hasPendingWrites &&
            doc.exists &&
            _remote.auth.currentUser?.emailVerified == true &&
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

  /// Forces an ID-token refresh so the `email_verified` claim is present
  /// before any verified-only Firestore reads run. signIn/restore mint a
  /// token that can momentarily lack the claim; without this the home
  /// shell's verified-only listeners (peers, announcements) hit
  /// PERMISSION_DENIED, and a failed Firestore listen never recovers.
  /// Mirror of the getIdToken(true) call in reloadAndCheckVerified.
  Future<void> _refreshTokenIfVerified() async {
    try {
      final user = _remote.auth.currentUser;
      if (user?.emailVerified == true) await user!.getIdToken(true);
    } catch (_) {
      // Non-fatal — reads may flash an error until the next token refresh.
    }
  }

  Future<void> _updateFcmToken(String uid) async {
    final messaging = _messaging;
    if (messaging == null) return;

    // Attach the refresh listener FIRST, before the getToken() attempt below.
    // On iOS the first getToken() can throw `apns-token-not-set`; if the
    // listener were attached after it (as it once was), that throw would skip
    // the listener and the token iOS issues moments later — once registration
    // completes — would never be written. Captured here, a late token still
    // lands in Firestore.
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = messaging.onTokenRefresh.listen((t) {
      _writeToken(uid, t);
    });

    try {
      // iOS: getToken() throws `apns-token-not-set` if the APNs token hasn't
      // been registered yet. Registration only happens once
      // requestPermission() has run, and that call otherwise lives in
      // FcmService.init() — mounted by the home shell AFTER this runs on
      // sign-in/startup. Calling it here (idempotent) guarantees iOS has
      // registered for remote notifications before we poll for the APNs token,
      // so getToken() doesn't throw. Android returns immediately and is
      // unaffected.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await messaging.requestPermission(alert: true, badge: true, sound: true);
        await _awaitApnsToken(messaging);
      }
      final token = await messaging.getToken();
      debugPrint(
        '[FCM] getToken for $uid -> ${token == null ? 'NULL' : '${token.substring(0, 12)}… (len ${token.length})'}',
      );
      if (token != null) await _writeToken(uid, token);
    } catch (e) {
      debugPrint('[FCM] token update failed — $e');
    }
  }

  /// Polls for the iOS APNs token (up to ~5s) so the subsequent getToken()
  /// call doesn't throw `apns-token-not-set`. Returns once available or after
  /// the timeout — getToken() then surfaces any remaining error to the caller.
  Future<void> _awaitApnsToken(FirebaseMessaging messaging) async {
    for (var i = 0; i < 10; i++) {
      final apns = await messaging.getAPNSToken();
      if (apns != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  // Always writes the token to users/{uid}/private/fcm. We intentionally do
  // NOT short-circuit on a locally cached "last token": that optimization
  // silently breaks delivery whenever local cache and Firestore diverge (app
  // reinstall, a write that never landed, a server-side token cleanup) — the
  // device keeps a valid token but never re-writes it, so the server has
  // nothing to send to. The doc lives in /private specifically so this write
  // doesn't fan out to user-collection listeners, making an idempotent write
  // on each startup/sign-in/refresh cheap and safe.
  Future<void> _writeToken(String uid, String token) async {
    try {
      await _remote.writeFcmToken(uid, token);
      debugPrint('[FCM] token WRITTEN to users/$uid/private/fcm');
    } catch (e) {
      debugPrint('[FCM] token write FAILED — $e');
    }
  }

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _remote.signIn(email.trim(), password);
      await _credentials.save(email.trim(), password);
      await ready;
      await _refreshTokenIfVerified();
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code);
    }
  }

  @override
  Future<CoachPromotion> register({
    required String name,
    required String email,
    required String password,
    String? gender,
    DateTime? dateOfBirth,
    int? heightCm,
    int? weightKg,
    required String role,
    required String coachKey,
    XFile? photoFile,
  }) async {
    final UserCredential cred;
    try {
      cred = await _remote.createAccount(email.trim(), password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code);
    }

    await _credentials.save(email.trim(), password);

    String? photoUrl;
    if (photoFile != null) {
      photoUrl =
          await _remote.uploadProfilePhoto(cred.user!.uid, photoFile.path);
    }

    // Firestore rules require role == 'player' at create. Coaches are
    // promoted server-side by validateCoachKey below.
    final user = UserModel(
      uid: cred.user!.uid,
      name: name.trim(),
      gender: gender,
      dateOfBirth: dateOfBirth,
      role: 'player',
      photoUrl: photoUrl,
      createdAt: DateTime.now(),
      heightCm: heightCm,
      weightKg: weightKg,
    );
    await _remote.createUserDoc(user, photoUrl);
    _emit(user);

    var promotion = CoachPromotion.notRequested;
    if (role == 'coach') {
      try {
        final promoted = await _remote.validateCoachKey(coachKey);
        promotion =
            promoted ? CoachPromotion.promoted : CoachPromotion.invalidKey;
      } catch (_) {
        promotion = CoachPromotion.networkError;
      }
    }

    try {
      await cred.user?.sendEmailVerification();
    } catch (_) {
      // Non-fatal — user can resend from the verify screen.
    }

    return promotion;
  }

  @override
  Future<void> signOut() async {
    await _credentials.clear();
    await _remote.signOut();
    _emit(null);
  }

  @override
  Future<void> deleteOwnAccount() async {
    try {
      await _remote.deleteMyAccount();
    } catch (_) {
      // The account was not deleted — keep the user signed in so they can
      // retry, and surface a failure to presentation.
      throw const AuthException('delete-failed');
    }
    // Backend deletion succeeded; tear down the local session.
    await signOut();
  }

  @override
  Future<void> sendVerificationEmail() async {
    try {
      await _remote.auth.currentUser?.sendEmailVerification();
    } catch (_) {
      throw const AuthException('unknown');
    }
  }

  @override
  Future<bool> reloadAndCheckVerified() async {
    try {
      await _remote.auth.currentUser?.reload();
      final verified = _remote.auth.currentUser?.emailVerified ?? false;
      if (verified) {
        // CRITICAL: reload() refreshes user fields but NOT the ID token.
        // Firestore authenticates via the ID token, which still carries the
        // stale `email_verified: false` claim until forced. Without this,
        // the isVerified() rule rejects queries immediately after verify.
        await _remote.auth.currentUser?.getIdToken(true);
      }
      return verified;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> markVerifiedAt() async {
    final uid = _remote.auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _remote
          .updateUserDoc(uid, {'verifiedAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // Cleanup function will heal this on its next pass.
    }
  }

  @override
  Future<void> updatePendingEmail(String newEmail) async {
    final user = _remote.auth.currentUser;
    if (user == null) throw const AuthException('unknown');
    try {
      await user.verifyBeforeUpdateEmail(newEmail.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code);
    } catch (_) {
      throw const AuthException('unknown');
    }
    try {
      // Reset the cleanup clock so cleanupUnverifiedUsers won't sweep this
      // user during the new verification window.
      await _remote
          .updateUserDoc(user.uid, {'createdAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // Non-fatal — if this fails the user might be cleaned up early.
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _remote.auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code);
    }
  }

  @override
  Future<void> updateProfilePhoto(XFile image) async {
    final uid = _lastUser?.uid;
    if (uid == null) return;
    final url = await _remote.uploadProfilePhoto(uid, image.path);
    await _remote.updateUserDoc(uid, {'photoUrl': url});
  }

  @override
  Future<void> updateBodyMetrics(
      {required int heightCm, required int weightKg}) async {
    final uid = _lastUser?.uid;
    if (uid == null) return;
    await _remote
        .updateUserDoc(uid, {'heightCm': heightCm, 'weightKg': weightKg});
  }

  @override
  Future<void> updateProfileBasics(
      {String? gender, DateTime? dateOfBirth}) async {
    final uid = _lastUser?.uid;
    if (uid == null) return;
    // Only writes the provided fields. The set-once rule guarantees this can
    // fill a missing value but never overwrite one that's already set.
    final data = <String, dynamic>{
      'gender': ?gender,
      if (dateOfBirth != null) 'dateOfBirth': Timestamp.fromDate(dateOfBirth),
    };
    if (data.isEmpty) return;
    await _remote.updateUserDoc(uid, data);
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _userSub?.cancel();
    await _authStateSub?.cancel();
    await _tokenRefreshSub?.cancel();
    await _userController.close();
  }
}
