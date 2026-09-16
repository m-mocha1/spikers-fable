/// Thrown when an account-management Cloud Function call (e.g.
/// `adminDeleteUser`) is rejected. [code] is the FirebaseFunctionsException
/// code — presentation maps it to a localized message. Mirrors
/// `SessionActionException` in the sessions feature.
class AccountActionException implements Exception {
  final String code;
  const AccountActionException(this.code);

  @override
  String toString() => 'AccountActionException($code)';
}
