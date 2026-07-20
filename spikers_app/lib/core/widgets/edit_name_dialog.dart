import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../utils/app_snackbar.dart';
import '../utils/validators.dart';
import '../../l10n/app_localizations.dart';
import 'branded_text_field.dart';

/// Maximum display-name length, mirrored from the Firestore `isValidName` rule
/// (and the `coachRenamePlayer` callable) so the client fails fast.
const int kMaxNameLength = 80;

/// Shared name-editing dialog. Used both by a player editing their own name and
/// by a coach renaming another player — the caller supplies [onSubmit], which
/// performs the actual write (a repository call). On success the dialog pops;
/// on failure it shows a generic error snackbar and stays open.
Future<void> showEditNameDialog(
  BuildContext context, {
  required String initialName,
  required Future<void> Function(String name) onSubmit,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) =>
        _EditNameDialog(initialName: initialName, onSubmit: onSubmit),
  );
}

class _EditNameDialog extends StatefulWidget {
  final String initialName;
  final Future<void> Function(String name) onSubmit;
  const _EditNameDialog({required this.initialName, required this.onSubmit});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit(_nameCtrl.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnackbar(l.nameUpdated);
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
                child: const Icon(Icons.badge_outlined,
                    color: AppColors.gold, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                l.editName,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              BrandedTextField(
                label: l.name,
                hint: l.nameHint,
                controller: _nameCtrl,
                autofocus: true,
                // The dialog surface is navyLight — use the darker navy fill
                // so the field stays visible.
                fillColor: AppColors.navyBlue,
                onSubmitted: (_) => _save(),
                validator: (v) {
                  final req = Validators.required(v, l.requiredField);
                  if (req != null) return req;
                  if (v!.trim().length > kMaxNameLength) return l.invalidName;
                  return null;
                },
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
