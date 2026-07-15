import '../entities/payment_record.dart';

abstract class PaymentsRepository {
  /// Streams a user's payment audit log, newest entry first.
  Stream<List<PaymentRecord>> watchHistory(String userId);

  /// Date of [userId]'s most recent 'paid' entry, or null if they never paid —
  /// feeds the attendance export's "last payment" column.
  Future<DateTime?> fetchLastPaidAt(String userId);
}
