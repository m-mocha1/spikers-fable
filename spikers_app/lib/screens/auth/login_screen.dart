import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/auth_controller.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../routes/app_routes.dart';
import '../widgets/branded_button.dart';
import '../widgets/branded_text_field.dart';
import '../../l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;

  final _auth = Get.find<AuthController>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _auth.signIn(_emailCtrl.text, _passCtrl.text);
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
                        onPressed: () => Get.toNamed(Routes.forgotPassword),
                        child: Text(l.forgotPassword),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Obx(() => BrandedButton(
                          label: l.signIn,
                          onPressed: _submit,
                          isLoading: _auth.isLoading.value,
                        )),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(l.noAccount,
                            style: const TextStyle(color: AppColors.grey)),
                        TextButton(
                          onPressed: () => Get.toNamed(Routes.register),
                          child: Text(l.register),
                        ),
                      ],
                    ),
                  ],
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
          Image.asset(AppAssets.splashBg, fit: BoxFit.cover),
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
