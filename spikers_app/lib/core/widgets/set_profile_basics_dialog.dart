import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_snackbar.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../l10n/app_localizations.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import 'branded_text_field.dart';

/// Lets a user fill in gender and/or date of birth when they're not set yet.
/// Only the missing field(s) are shown. The Firestore rules enforce set-once,
/// so this can never change an already-set value.
Future<void> showSetProfileBasicsDialog(BuildContext context, UserModel user) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => _SetProfileBasicsDialog(user: user),
  );
}

class _SetProfileBasicsDialog extends ConsumerStatefulWidget {
  final UserModel user;
  const _SetProfileBasicsDialog({required this.user});

  @override
  ConsumerState<_SetProfileBasicsDialog> createState() =>
      _SetProfileBasicsDialogState();
}

class _SetProfileBasicsDialogState
    extends ConsumerState<_SetProfileBasicsDialog> {
  final _dobCtrl = TextEditingController();
  String? _gender;
  DateTime? _dob;
  bool _saving = false;

  bool get _needGender => widget.user.gender == null;
  bool get _needDob => widget.user.dateOfBirth == null;

  @override
  void dispose() {
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1950),
      // At least 13 years old, matching the isValidDob rule so the write
      // can't be rejected.
      lastDate: DateTime(now.year - 13),
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

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    if (_needGender && _gender == null) {
      showAppSnackbar(l.requiredField);
      return;
    }
    if (_needDob && _dob == null) {
      showAppSnackbar(l.requiredField);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateProfileBasics(
            gender: _needGender ? _gender : null,
            dateOfBirth: _needDob ? _dob : null,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackbar(l.unknownError);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: const Icon(Icons.badge_outlined,
                    color: AppColors.gold, size: 28),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                l.completeProfile,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_needGender) ...[
              Text(l.gender,
                  style: const TextStyle(
                      color: AppColors.gold, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _GenderChip(
                    label: l.male,
                    selected: _gender == 'male',
                    onTap: () => setState(() => _gender = 'male'),
                  ),
                  const SizedBox(width: 12),
                  _GenderChip(
                    label: l.female,
                    selected: _gender == 'female',
                    onTap: () => setState(() => _gender = 'female'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (_needDob) ...[
              BrandedTextField(
                label: l.dateOfBirth,
                hint: l.selectDate,
                controller: _dobCtrl,
                readOnly: true,
                onTap: _pickDate,
                suffixIcon: const Icon(Icons.calendar_today_outlined,
                    color: AppColors.grey),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 4),
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
                                strokeWidth: 2, color: AppColors.navyBlue))
                        : Text(l.save,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
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
          color: selected ? AppColors.gold : AppColors.navyBlue,
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
