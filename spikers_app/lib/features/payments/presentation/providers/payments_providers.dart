import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/datasources/payments_remote_datasource.dart';
import '../../data/repositories/payments_repository_impl.dart';
import '../../domain/entities/payment_record.dart';
import '../../domain/repositories/payments_repository.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepositoryImpl(
    PaymentsRemoteDataSource(ref.watch(firestoreProvider)),
  ),
);

final paymentHistoryProvider =
    StreamProvider.autoDispose.family<List<PaymentRecord>, String>(
  (ref, uid) => ref.watch(paymentsRepositoryProvider).watchHistory(uid),
);
