import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart' show Get, GetNavigation;

import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import '../../../../routes/app_routes.dart';
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

/// Signs out and returns to the login screen. Feature state that keys off
/// currentUserProvider (sessions, notifications, ...) resets itself when the
/// user stream emits null.
Future<void> signOutToLogin(WidgetRef ref) async {
  await ref.read(authRepositoryProvider).signOut();
  Get.offAllNamed(Routes.login);
}
