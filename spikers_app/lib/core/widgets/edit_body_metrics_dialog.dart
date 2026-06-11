import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart' show ExtensionSnackbar, Get, SnackPosition;
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../l10n/app_localizations.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import 'branded_text_field.dart';

Future<void> showEditBodyMetricsDialog(
  BuildContext context,
  UserModel user,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => _EditBodyMetricsDialog(user: user),
  );
}

class _EditBodyMetricsDialog extends ConsumerStatefulWidget {
  final UserModel user;
  const _EditBodyMetricsDialog({required this.user});

  @override
  ConsumerState<_EditBodyMetricsDialog> createState() =>
      _EditBodyMetricsDialogState();
}

class _EditBodyMetricsDialogState
    extends ConsumerState<_EditBodyMetricsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _heightCtrl =
        TextEditingController(text: widget.user.heightCm?.toString() ?? '');
    _weightCtrl =
        TextEditingController(text: widget.user.weightKg?.toString() ?? '');
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateBodyMetrics(
            heightCm: int.parse(_heightCtrl.text.trim()),
            weightKg: int.parse(_weightCtrl.text.trim()),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      Get.snackbar('', l.unknownError, snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: AppColors.navyLight,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: const Icon(Icons.straighten,
                    color: AppColors.gold, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                l.editBodyMetrics,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              BrandedTextField(
                label: l.height,
                hint: l.heightHint,
                controller: _heightCtrl,
                keyboardType: TextInputType.number,
                validator: (v) => Validators.intInRange(v,
                    min: 100,
                    max: 250,
                    emptyMsg: l.requiredField,
                    invalidMsg: l.invalidHeight),
              ),
              const SizedBox(height: 12),
              BrandedTextField(
                label: l.weight,
                hint: l.weightHint,
                controller: _weightCtrl,
                keyboardType: TextInputType.number,
                validator: (v) => Validators.intInRange(v,
                    min: 20,
                    max: 200,
                    emptyMsg: l.requiredField,
                    invalidMsg: l.invalidWeight),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(l.cancel,
                          style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.navyBlue,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.navyBlue))
                          : Text(l.save,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
