import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/core/widgets/branded_button.dart';
import 'package:spikers_app/core/widgets/branded_text_field.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';
import '../utils/auth_error_l10n.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) return;
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(authRepositoryProvider);
    setState(() => _loading = true);
    try {
      await repo.signIn(_emailCtrl.text, _passCtrl.text);
      if (!mounted) return;
      context.go(repo.isEmailVerified ? Routes.home : Routes.verifyEmail);
    } on AuthException catch (e) {
      showAppSnackbar(authErrorMessage(l, e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 32, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BrandedTextField(
                      label: l.email,
                      hint: l.emailHint,
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => Validators.email(v,
                          emptyMsg: l.requiredField,
                          invalidMsg: l.invalidEmail),
                    ),
                    const SizedBox(height: 16),
                    BrandedTextField(
                      label: l.password,
                      hint: l.passwordHint,
                      controller: _passCtrl,
                      obscureText: !_showPass,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPass ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.grey,
                        ),
                        onPressed: () => setState(() => _showPass = !_showPass),
                      ),
                      validator: (v) => Validators.password(v,
                          emptyMsg: l.requiredField,
                          shortMsg: l.passwordTooShort),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () =>
                            context.push(Routes.forgotPassword),
                        child: Text(l.forgotPassword),
                      ),
                    ),
                    const SizedBox(height: 8),
                    BrandedButton(
                      label: l.signIn,
                      onPressed: _submit,
                      isLoading: _loading,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l.noAccount,
                            style: const TextStyle(color: AppColors.grey)),
                        TextButton(
                          onPressed: () => context.push(Routes.register),
                          child: Text(l.register),
                        ),
                      ],
                    ),
                  ]
                      .animate(interval: AppMotion.stagger)
                      .fadeIn(duration: AppMotion.normal, curve: AppMotion.enter)
                      .slideY(begin: 0.18, end: 0, curve: AppMotion.enter),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.36,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.splashBg, fit: BoxFit.cover)
              .animate()
              .fadeIn(duration: AppMotion.slow)
              .scale(
                begin: const Offset(1.08, 1.08),
                end: const Offset(1.0, 1.0),
                duration: const Duration(milliseconds: 1600),
                curve: Curves.easeOut,
              ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.navyBlue],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
