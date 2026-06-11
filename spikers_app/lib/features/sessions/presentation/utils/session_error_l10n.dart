import '../../../../l10n/app_localizations.dart';

/// Maps SessionActionException codes from the join/leave path to localized
/// messages. Unknown codes surface the raw code so unexpected failures stay
/// diagnosable during early-stage testing.
String joinErrorMessage(AppLocalizations l, String code) {
  switch (code) {
    case 'failed-precondition':
      return l.sessionFull;
    case 'not-found':
      return l.sessionMissing;
    case 'unauthenticated':
      return l.notSignedIn;
    default:
      return '${l.unknownError} ($code)';
  }
}

String cancelErrorMessage(AppLocalizations l, String code) {
  switch (code) {
    case 'permission-denied':
      return l.notYourSession;
    case 'not-found':
      return l.sessionMissing;
    case 'unauthenticated':
      return l.notSignedIn;
    default:
      return '${l.unknownError} ($code)';
  }
}

String capacityErrorMessage(AppLocalizations l, String code) {
  switch (code) {
    case 'failed-precondition':
      return l.capacityMustNotDecrease;
    case 'permission-denied':
      return l.notYourSession;
    case 'invalid-argument':
      return l.nothingToUpdate;
    case 'not-found':
      return l.sessionMissing;
    case 'unauthenticated':
      return l.notSignedIn;
    default:
      return '${l.unknownError} ($code)';
  }
}
