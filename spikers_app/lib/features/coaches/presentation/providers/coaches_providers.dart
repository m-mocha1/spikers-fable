import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/datasources/coaches_remote_datasource.dart';
import '../../data/repositories/coaches_repository_impl.dart';
import '../../domain/entities/coach_summary.dart';
import '../../domain/repositories/coaches_repository.dart';

final coachesRepositoryProvider = Provider<CoachesRepository>(
  (ref) => CoachesRepositoryImpl(
    CoachesRemoteDataSource(ref.watch(firestoreProvider)),
  ),
);

final coachesProvider = StreamProvider.autoDispose<List<CoachSummary>>(
  (ref) => ref.watch(coachesRepositoryProvider).watchCoaches(),
);
