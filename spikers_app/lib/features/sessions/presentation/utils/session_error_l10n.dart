import '../../../../l10n/app_localizations.dart';

/// Callable failures caused by the network rather than the request itself:
/// the client timeout ('deadline-exceeded') or no connection ('unavailable').
/// Shared by every mapper below so a slow network never reads as a bug.
String? _networkErrorMessage(AppLocalizations l, String code) =>
    code == 'deadline-exceeded' || code == 'unavailable'
        ? l.slowConnection
        : null;

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
      return _networkErrorMessage(l, code) ?? '${l.unknownError} ($code)';
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
      return _networkErrorMessage(l, code) ?? '${l.unknownError} ($code)';
  }
}

/// Maps failures from the coach "add players to this session" path.
String addAttendeeErrorMessage(AppLocalizations l, String code) {
  switch (code) {
    case 'permission-denied':
      return l.notYourSession;
    case 'failed-precondition':
      return l.notASessionMember;
    case 'not-found':
      return l.sessionMissing;
    case 'invalid-argument':
      return l.nothingToUpdate;
    case 'unauthenticated':
      return l.notSignedIn;
    default:
      return _networkErrorMessage(l, code) ?? '${l.unknownError} ($code)';
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
      return _networkErrorMessage(l, code) ?? '${l.unknownError} ($code)';
  }
}

/// Failures from the coach "shift this session's time" path. Kept separate from
/// [capacityErrorMessage] because the two disagree on what 'failed-precondition'
/// and 'invalid-argument' mean.
String timeErrorMessage(AppLocalizations l, String code) {
  switch (code) {
    // The session started — a deliberate rule, not a glitch, so say which.
    case 'failed-precondition':
      return l.sessionAlreadyStarted;
    case 'invalid-argument':
      return l.invalidSessionTime;
    case 'permission-denied':
      return l.notYourSession;
    case 'not-found':
      return l.sessionMissing;
    case 'unauthenticated':
      return l.notSignedIn;
    default:
      return _networkErrorMessage(l, code) ?? '${l.unknownError} ($code)';
  }
}
