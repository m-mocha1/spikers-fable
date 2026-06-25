import '../../domain/entities/payment_record.dart';
import '../../domain/repositories/payments_repository.dart';
import '../datasources/payments_remote_datasource.dart';

class PaymentsRepositoryImpl implements PaymentsRepository {
  final PaymentsRemoteDataSource _remote;

  PaymentsRepositoryImpl(this._remote);

  @override
  Stream<List<PaymentRecord>> watchHistory(String userId) =>
      _remote.watchHistory(userId);
}
