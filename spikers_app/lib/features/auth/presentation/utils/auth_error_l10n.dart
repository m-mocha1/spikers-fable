import '../../../../l10n/app_localizations.dart';

/// Maps FirebaseAuth error codes (via AuthException.code) to localized
/// messages. The old GetX controller used `.tr` with no registered
/// translations, which showed raw keys like "wrongPassword" to users.
String authErrorMessage(AppLocalizations l, String code) {
  switch (code) {
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return l.wrongPassword;
    case 'invalid-email':
      return l.invalidEmail;
    case 'email-already-in-use':
      return l.emailAlreadyInUse;
    case 'weak-password':
      return l.passwordTooShort;
    case 'too-many-requests':
      return l.tooManyRequests;
    case 'user-disabled':
      return l.userDisabled;
    case 'network-request-failed':
      return l.networkError;
    case 'requires-recent-login':
      return l.sessionExpired;
    default:
      return l.unknownError;
  }
}
