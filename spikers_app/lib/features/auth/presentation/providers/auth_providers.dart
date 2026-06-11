import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/user_model.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

/// Backed by the shared production instance so the GetX shim and Riverpod
/// observe the same session. Tests override this provider with a fake.
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepositoryImpl.instance);

final currentUserProvider = StreamProvider<UserModel?>(
    (ref) => ref.watch(authRepositoryProvider).watchCurrentUser());

final isCoachProvider = Provider<bool>(
    (ref) => ref.watch(currentUserProvider).value?.isCoach ?? false);
