import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/players_remote_datasource.dart';
import '../../data/repositories/players_repository_impl.dart';
import '../../domain/entities/player_summary.dart';
import '../../domain/repositories/players_repository.dart';

final playersRepositoryProvider = Provider<PlayersRepository>(
  (ref) => PlayersRepositoryImpl(
    PlayersRemoteDataSource(
      ref.watch(firestoreProvider),
      ref.watch(firebaseFunctionsProvider),
    ),
  ),
);

final playersProvider = StreamProvider.autoDispose<List<PlayerSummary>>(
  (ref) => ref.watch(playersRepositoryProvider).watchPlayers(),
);

final peersProvider = StreamProvider.autoDispose<List<PeerSummary>>((ref) {
  final me = ref.watch(currentUserProvider).value;
  if (me == null) return const Stream.empty();
  // users_public reads require email_verified in the rules; return empty
  // instead of hitting PERMISSION_DENIED while unverified. Re-subscribes
  // once verification flips (currentUser re-emits). See upcomingSessionsProvider.
  if (!ref.watch(authRepositoryProvider).isEmailVerified) {
    return Stream.value(const []);
  }
  return ref
      .watch(playersRepositoryProvider)
      .watchPeers(myUid: me.uid, myGender: me.gender);
});

final playerProvider =
    StreamProvider.autoDispose.family<UserModel?, String>(
  (ref, uid) => ref.watch(playersRepositoryProvider).watchPlayer(uid),
);
