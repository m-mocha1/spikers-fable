import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/media_permissions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/core/widgets/animations.dart';
import 'package:spikers_app/core/widgets/branded_button.dart';
import 'package:spikers_app/core/widgets/branded_text_field.dart';
import '../../domain/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';
import '../utils/auth_error_l10n.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _coachKeyCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  bool _showPass = false;
  bool _showConfirm = false;
  String? _gender; // optional — null means "not provided"
  String _role = 'player';
  DateTime? _dob;
  XFile? _photoFile;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _coachKeyCtrl.dispose();
    _dobCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            surface: AppColors.navyLight,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showPhotoPicker(AppLocalizations l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.navyLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.gold),
              title: Text(l.pickFromGallery),
              onTap: () {
                Navigator.of(context).pop();
                _pickPhoto(ImageSource.gallery, l);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.gold),
              title: Text(l.takePhoto),
              onTap: () {
                Navigator.of(context).pop();
                _pickPhoto(ImageSource.camera, l);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source, AppLocalizations l) async {
    final bool granted;
    if (source == ImageSource.camera) {
      granted = await ensureCameraPermission(context, l);
    } else {
      granted = await ensurePhotoPermission(context, l);
    }
    if (!granted || !mounted) return;
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (file != null) setState(() => _photoFile = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) return;
    final l = AppLocalizations.of(context)!;
    setState(() => _loading = true);
    try {
      final promotion = await ref.read(authRepositoryProvider).register(
            name: _nameCtrl.text,
            email: _emailCtrl.text,
            password: _passCtrl.text,
            gender: _gender,
            dateOfBirth: _dob,
            heightCm: int.tryParse(_heightCtrl.text.trim()),
            weightKg: int.tryParse(_weightCtrl.text.trim()),
            role: _role,
            coachKey: _coachKeyCtrl.text,
            photoFile: _photoFile,
          );
      switch (promotion) {
        case CoachPromotion.invalidKey:
          // User stays a player; they keep the account and can retry coach
          // promotion later. Continue to verify-email either way.
          showAppSnackbar(l.invalidCoachKey);
        case CoachPromotion.networkError:
          showAppSnackbar(l.networkError);
        case CoachPromotion.notRequested:
        case CoachPromotion.promoted:
          break;
      }
      if (!mounted) return;
      context.go(Routes.verifyEmail);
    } on AuthException catch (e) {
      showAppSnackbar(authErrorMessage(l, e.code));
    } catch (_) {
      // Any non-auth failure (e.g. a rejected user-doc write) must surface
      // rather than silently leaving the user on the form.
      showAppSnackbar(l.errorOccurred);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.register)),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 40),
        child: AppFadeIn(
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Photo picker ---
              Center(
                child: GestureDetector(
                  onTap: () => _showPhotoPicker(l),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.navyLight,
                        backgroundImage: _photoFile != null
                            ? FileImage(File(_photoFile!.path))
                                as ImageProvider
                            : null,
                        child: _photoFile == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.camera_alt_outlined,
                                      color: AppColors.gold, size: 28),
                                  const SizedBox(height: 4),
                                  Text(
                                    l.addPhoto,
                                    style: const TextStyle(
                                        color: AppColors.grey, fontSize: 10),
                                  ),
                                ],
                              )
                            : null,
                      ),
                      if (_photoFile != null)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.navyBlue, width: 2),
                          ),
                          child: const Icon(Icons.edit,
                              size: 12, color: AppColors.navyBlue),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              BrandedTextField(
                label: l.name,
                hint: l.nameHint,
                controller: _nameCtrl,
                validator: (v) => Validators.required(v, l.requiredField),
              ),
              const SizedBox(height: 16),
              BrandedTextField(
                label: l.email,
                hint: l.emailHint,
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => Validators.email(v,
                    emptyMsg: l.requiredField, invalidMsg: l.invalidEmail),
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
                    emptyMsg: l.requiredField, shortMsg: l.passwordTooShort),
              ),
              const SizedBox(height: 16),
              BrandedTextField(
                label: l.confirmPassword,
                hint: l.confirmPasswordHint,
                controller: _confirmCtrl,
                obscureText: !_showConfirm,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirm ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.grey,
                  ),
                  onPressed: () =>
                      setState(() => _showConfirm = !_showConfirm),
                ),
                validator: (v) => Validators.confirmPassword(
                    v, _passCtrl.text,
                    mismatchMsg: l.passwordsDoNotMatch),
              ),
              const SizedBox(height: 24),

              // --- Gender (optional) ---
              Text('${l.gender} (${l.optional})',
                  style: const TextStyle(
                      color: AppColors.gold, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _GenderChip(
                    label: l.male,
                    selected: _gender == 'male',
                    // Tapping a selected chip clears it — gender is optional.
                    onTap: () => setState(
                        () => _gender = _gender == 'male' ? null : 'male'),
                  ),
                  const SizedBox(width: 12),
                  _GenderChip(
                    label: l.female,
                    selected: _gender == 'female',
                    onTap: () => setState(
                        () => _gender = _gender == 'female' ? null : 'female'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Date of Birth (optional) ---
              BrandedTextField(
                label: '${l.dateOfBirth} (${l.optional})',
                hint: l.selectDate,
                controller: _dobCtrl,
                readOnly: true,
                onTap: _pickDate,
                suffixIcon: const Icon(Icons.calendar_today_outlined,
                    color: AppColors.grey),
              ),
              const SizedBox(height: 16),

              // --- Height & Weight (optional) ---
              Row(
                children: [
                  Expanded(
                    child: BrandedTextField(
                      label: '${l.height} (${l.optional})',
                      hint: l.heightHint,
                      controller: _heightCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) => Validators.optionalIntInRange(v,
                          min: 100, max: 250, invalidMsg: l.invalidHeight),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BrandedTextField(
                      label: '${l.weight} (${l.optional})',
                      hint: l.weightHint,
                      controller: _weightCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) => Validators.optionalIntInRange(v,
                          min: 20, max: 200, invalidMsg: l.invalidWeight),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Role ---
              Text(l.role,
                  style: const TextStyle(
                      color: AppColors.gold, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _GenderChip(
                    label: l.player,
                    selected: _role == 'player',
                    onTap: () => setState(() => _role = 'player'),
                  ),
                  const SizedBox(width: 12),
                  _GenderChip(
                    label: l.coach,
                    selected: _role == 'coach',
                    onTap: () => setState(() => _role = 'coach'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Coach Key (animated) ---
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _role == 'coach'
                    ? Padding(
                        key: const ValueKey('coachKey'),
                        padding: const EdgeInsets.only(bottom: 16),
                        child: BrandedTextField(
                          label: l.coachKey,
                          hint: l.coachKeyHint,
                          controller: _coachKeyCtrl,
                          validator: (v) => _role == 'coach'
                              ? Validators.required(v, l.requiredField)
                              : null,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),

              const SizedBox(height: 8),
              BrandedButton(
                label: l.register,
                onPressed: _submit,
                isLoading: _loading,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l.haveAccount,
                      style: const TextStyle(color: AppColors.grey)),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(l.signIn),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenderChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : AppColors.navyLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.grey,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.navyBlue : AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
