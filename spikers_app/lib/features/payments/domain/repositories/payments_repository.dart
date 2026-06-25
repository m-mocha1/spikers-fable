import '../entities/payment_record.dart';

abstract class PaymentsRepository {
  /// Streams a user's payment audit log, newest entry first.
  Stream<List<PaymentRecord>> watchHistory(String userId);
}
