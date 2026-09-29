import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import '../../../../core/router/app_router.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

/// Backed by the shared production instance so the GetX shim and Riverpod
/// observe the same session. Tests override this provider with a fake.
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepositoryImpl.instance);

final currentUserProvider = StreamProvider<UserModel?>(
    (ref) => ref.watch(authRepositoryProvider).watchCurrentUser());

/// The signed-in user for building Firestore *queries*. Re-notifies only when
/// something that changes what a query may return changes: identity, role,
/// gender, age, membership, profile completeness or email verification.
///
/// Watching [currentUserProvider] directly re-runs a provider on every user-doc
/// write (a coach renewing membership, attendanceCount ticking up, the
/// verifiedAt heal…). For a query provider that tears down the listener and
/// re-downloads the whole list, which is painful on a slow network. Widgets
/// that *display* user fields should keep watching [currentUserProvider].
final queryViewerProvider = Provider<UserModel?>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  ref.watch(currentUserProvider.select((async) {
    final u = async.value;
    if (u == null) return null;
    return (
      u.uid,
      u.isCoach,
      u.gender,
      u.age,
      u.isPaid,
      u.hasCompleteProfile,
      // Not a user-doc field, but sampled on every user emission — this keeps
      // the old "re-subscribe once verification flips" behavior.
      auth.isEmailVerified,
    );
  }));
  return ref.read(currentUserProvider).value;
});

final isCoachProvider = Provider<bool>(
    (ref) => ref.watch(currentUserProvider).value?.isCoach ?? false);

final isAdminProvider = Provider<bool>(
    (ref) => ref.watch(currentUserProvider).value?.isAdmin ?? false);

/// Signs out and returns to the login screen. Feature state that keys off
/// currentUserProvider (sessions, notifications, ...) resets itself when the
/// user stream emits null.
Future<void> signOutToLogin(WidgetRef ref) async {
  await ref.read(authRepositoryProvider).signOut();
  appRouter.go(Routes.login);
}
