import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart' show Get, GetNavigation;

import '../../../../core/constants/app_assets.dart';
import '../../../../routes/app_routes.dart';
import '../providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    _navigate();
  }

  Future<void> _navigate() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.ready;
    if (!mounted) return;
    if (repo.isSignedIn) {
      Get.offAllNamed(
          repo.isEmailVerified ? Routes.home : Routes.verifyEmail);
    } else {
      Get.offAllNamed(Routes.login);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.splashBg, fit: BoxFit.cover),
          FadeTransition(opacity: _fade),
        ],
      ),
    );
  }
}
