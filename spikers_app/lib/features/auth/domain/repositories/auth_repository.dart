import 'package:image_picker/image_picker.dart';

import 'package:spikers_app/features/auth/domain/entities/user_model.dart';

/// Thrown by repository methods when Firebase Auth rejects an operation.
/// [code] is the FirebaseAuthException code (or 'unknown') — presentation
/// maps it to a localized message.
class AuthException implements Exception {
  final String code;
  const AuthException(this.code);

  @override
  String toString() => 'AuthException($code)';
}

/// Outcome of the coach-key check during registration.
enum CoachPromotion { notRequested, promoted, invalidKey, networkError }

abstract class AuthRepository {
  /// Completes once session restore has been attempted and the first user
  /// snapshot (if signed in) has arrived. Splash gates navigation on this.
  Future<void> get ready;

  /// Current user document as a stream; null when signed out. Replays the
  /// latest value to new listeners.
  Stream<UserModel?> watchCurrentUser();

  UserModel? get currentUserNow;
  bool get isSignedIn;
  bool get isEmailVerified;
  String get currentEmail;

  /// Throws [AuthException] on failure. Saves credentials for silent restore.
  Future<void> signIn(String email, String password);

  /// Creates the account, uploads the photo, writes the user doc, and asks
  /// the backend to promote to coach when requested. Throws [AuthException]
  /// on auth failure; a failed coach promotion does NOT throw.
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
  });

  /// Clears stored credentials and signs out of Firebase.
  Future<void> signOut();

  /// Permanently deletes the caller's own account and all associated data via
  /// the backend, then signs out locally. Throws [AuthException] on failure.
  Future<void> deleteOwnAccount();

  Future<void> sendVerificationEmail();

  /// Reloads the Firebase user and, when verified, forces an ID-token
  /// refresh so Firestore rules see the new email_verified claim.
  Future<bool> reloadAndCheckVerified();

  /// Stamps verifiedAt on the user doc after a successful verification.
  Future<void> markVerifiedAt();

  /// Sends the verify-before-update email for an email change and bumps
  /// createdAt so the unverified-user cleanup doesn't sweep the account.
  /// Throws [AuthException] (invalid-email, email-already-in-use,
  /// requires-recent-login, unknown).
  Future<void> updatePendingEmail(String newEmail);

  Future<void> sendPasswordReset(String email);

  Future<void> updateProfilePhoto(XFile image);

  Future<void> updateBodyMetrics({required int heightCm, required int weightKg});

  /// Sets gender and/or date of birth. Only writes the provided fields; the
  /// Firestore rules enforce set-once (a missing value can be filled in, but
  /// an existing one cannot be changed).
  Future<void> updateProfileBasics({String? gender, DateTime? dateOfBirth});
}
