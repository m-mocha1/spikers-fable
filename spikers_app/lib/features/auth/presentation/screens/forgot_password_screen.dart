import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/core/widgets/branded_button.dart';
import 'package:spikers_app/core/widgets/branded_text_field.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';
import '../utils/auth_error_l10n.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) return;
    final l = AppLocalizations.of(context)!;
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordReset(_emailCtrl.text);
      if (!mounted) return;
      context.pop();
      showAppSnackbar(l.sendResetEmail,
          duration: const Duration(seconds: 4));
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
      appBar: AppBar(title: Text(l.forgotPassword)),
      // SafeArea keeps the form clear of the Android gesture bar.
      body: SafeArea(
        child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 40, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_reset_rounded,
                  color: AppColors.gold, size: 52),
              const SizedBox(height: 20),
              Text(
                l.forgotPassword,
                style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 32),
              BrandedTextField(
                label: l.email,
                hint: l.emailHint,
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => Validators.email(v,
                    emptyMsg: l.requiredField, invalidMsg: l.invalidEmail),
              ),
              const SizedBox(height: 32),
              BrandedButton(
                label: l.sendResetEmail,
                onPressed: _submit,
                isLoading: _loading,
              ),
            ]
                .animate(interval: AppMotion.stagger)
                .fadeIn(duration: AppMotion.normal, curve: AppMotion.enter)
                .slideY(begin: 0.18, end: 0, curve: AppMotion.enter),
          ),
        ),
        ),
      ),
    );
  }
}
