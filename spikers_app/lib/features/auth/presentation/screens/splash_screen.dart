import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/app_logo.dart';
import '../providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.ready;
    if (!mounted) return;
    if (repo.isSignedIn) {
      context.go(repo.isEmailVerified ? Routes.home : Routes.verifyEmail);
    } else {
      context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Slow zoom on the backdrop gives the splash a living, cinematic feel.
          Image.asset(AppAssets.splashBg, fit: BoxFit.cover)
              .animate()
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.08, 1.08),
                duration: const Duration(milliseconds: 2600),
                curve: Curves.easeOut,
              ),
          // Logo fades + lifts in, then breathes gently while auth resolves.
          Center(
            child: const AppLogo(width: 180)
                .animate()
                .fadeIn(duration: const Duration(milliseconds: 700))
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                )
                .then()
                .shimmer(
                  duration: const Duration(milliseconds: 1400),
                  color: Colors.white.withValues(alpha: 0.5),
                ),
          ),
        ],
      ),
    );
  }
}
