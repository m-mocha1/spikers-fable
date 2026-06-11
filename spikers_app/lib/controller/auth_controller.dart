import 'dart:async';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import 'notification_controller.dart';

/// MIGRATION SHIM — thin GetX facade over the Riverpod-era AuthRepository.
///
/// The auth feature itself lives in features/auth (repository + screens).
/// This class only keeps the old `Get.find<AuthController>()` surface alive
/// for not-yet-migrated consumers (home tabs, session screens, domain
/// controllers, CoachOnlyMiddleware). It owns no Firebase logic. Delete it
/// when the last GetX consumer migrates.
class AuthController extends GetxController {
  final _repo = AuthRepositoryImpl.instance;

  final Rxn<UserModel> currentUser = Rxn<UserModel>();
  final isLoading = false.obs;

  StreamSubscription? _userSub;

  bool get isCoach => currentUser.value?.isCoach ?? false;
  bool get isEmailVerified => _repo.isEmailVerified;
  String get currentEmail => _repo.currentEmail;
  bool get isSignedIn => _repo.isSignedIn;

  /// Splash used to await this before navigating; kept for any stragglers.
  Future<void> waitForAuth() => _repo.ready;

  @override
  void onInit() {
    super.onInit();
    _userSub = _repo.watchCurrentUser().listen((u) => currentUser.value = u);
  }

  @override
  void onClose() {
    _userSub?.cancel();
    super.onClose();
  }

  /// Throws on failure — caller owns user feedback.
  Future<void> updateProfilePhoto(XFile image) async {
    isLoading.value = true;
    try {
      await _repo.updateProfilePhoto(image);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateBodyMetrics({
    required int heightCm,
    required int weightKg,
  }) =>
      _repo.updateBodyMetrics(heightCm: heightCm, weightKg: weightKg);

  Future<void> signOut() async {
    await _repo.signOut();
    // Tear down the remaining permanent GetX controller so its listeners
    // don't survive into the next user's session. It rebuilds on the next
    // /home navigation via the route binding. (Riverpod feature state keys
    // off currentUserProvider and resets itself.)
    if (Get.isRegistered<NotificationController>()) {
      Get.delete<NotificationController>(force: true);
    }
    Get.offAllNamed(Routes.login);
  }
}
