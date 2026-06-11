import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/branded_button.dart';
import '../widgets/branded_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _auth = Get.find<AuthController>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _auth.sendPasswordReset(_emailCtrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.forgotPassword)),
      body: Padding(
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
              Obx(() => BrandedButton(
                    label: l.sendResetEmail,
                    onPressed: _submit,
                    isLoading: _auth.isLoading.value,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
