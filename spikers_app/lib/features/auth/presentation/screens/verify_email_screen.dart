import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/core/widgets/animations.dart';
import 'package:spikers_app/core/widgets/branded_button.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';
import '../utils/auth_error_l10n.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _resendCooldownSeconds = 60;

  int _resendIn = 0;
  Timer? _ticker;
  bool _checking = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    // We just sent one on register/signin; start cooldown so the resend
    // button doesn't immediately invite a duplicate.
    _startCooldown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _ticker?.cancel();
    setState(() => _resendIn = _resendCooldownSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _check() async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(authRepositoryProvider);
    setState(() => _checking = true);
    final verified = await repo.reloadAndCheckVerified();
    if (!mounted) return;
    setState(() => _checking = false);
    if (verified) {
      await repo.markVerifiedAt();
      if (!mounted) return;
      context.go(Routes.home);
    } else {
      showAppSnackbar(l.verifyEmailNotYet);
    }
  }

  Future<void> _resend() async {
    if (_resendIn > 0 || _resending) return;
    final l = AppLocalizations.of(context)!;
    setState(() => _resending = true);
    try {
      await ref.read(authRepositoryProvider).sendVerificationEmail();
      if (!mounted) return;
      showAppSnackbar(l.verifyEmailSent);
      _startCooldown();
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppSnackbar(authErrorMessage(l, e.code));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _changeEmail() async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(authRepositoryProvider);
    final newEmail = await showDialog<String>(
      context: context,
      builder: (_) => _ChangeEmailDialog(initialEmail: repo.currentEmail),
    );

    if (newEmail == null || !mounted) return;

    try {
      await repo.updatePendingEmail(newEmail);
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppSnackbar(authErrorMessage(l, e.code));
      return;
    }
    // Defer past the current frame so the dialog's InheritedElement dependents
    // have detached before go() disposes the route stack — otherwise the
    // framework trips `_dependents.isEmpty`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(Routes.emailChangeNotice, extra: newEmail);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final email = ref.read(authRepositoryProvider).currentEmail;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(24, 48, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Floating(
                        child: Icon(Icons.mark_email_unread_outlined,
                            color: AppColors.gold, size: 64),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l.verifyEmailTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.verifyEmailBody(email),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.grey,
                            fontSize: 14,
                            height: 1.5),
                      ),
                      const Spacer(),
                      BrandedButton(
                        label: l.verifyEmailContinue,
                        onPressed: _check,
                        isLoading: _checking,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed:
                              (_resendIn > 0 || _resending) ? null : _resend,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.gold),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _resending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.gold),
                                )
                              : Text(
                                  _resendIn > 0
                                      ? l.verifyEmailResendIn(_resendIn)
                                      : l.verifyEmailResend,
                                  style:
                                      const TextStyle(color: AppColors.gold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _changeEmail,
                        child: Text(l.changeEmail,
                            style: const TextStyle(color: AppColors.gold)),
                      ),
                      TextButton(
                        onPressed: () => signOutToLogin(ref),
                        child: Text(l.signOut,
                            style: const TextStyle(color: AppColors.grey)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangeEmailDialog extends StatefulWidget {
  final String initialEmail;
  const _ChangeEmailDialog({required this.initialEmail});

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.navyLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l.changeEmailTitle,
          style: const TextStyle(color: AppColors.white)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _ctrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          style: const TextStyle(color: AppColors.white),
          decoration: InputDecoration(
            hintText: l.changeEmailHint,
            hintStyle: const TextStyle(color: AppColors.grey),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.grey)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.gold)),
          ),
          validator: (v) => Validators.email(v,
              emptyMsg: l.requiredField, invalidMsg: l.invalidEmail),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child:
              Text(l.cancel, style: const TextStyle(color: AppColors.grey)),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_ctrl.text.trim());
            }
          },
          child: Text(l.changeEmailUpdate,
              style: const TextStyle(
                  color: AppColors.gold, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
