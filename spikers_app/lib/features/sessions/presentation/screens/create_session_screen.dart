import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_template_model.dart';
import 'package:spikers_app/core/widgets/animations.dart';
import 'package:spikers_app/core/widgets/branded_button.dart';
import 'package:spikers_app/core/widgets/branded_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/sessions_providers.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  ConsumerState<CreateSessionScreen> createState() =>
      _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _minAgeCtrl = TextEditingController(text: '16');
  final _maxAgeCtrl = TextEditingController(text: '40');
  final _maxPlayersCtrl = TextEditingController(text: '12');
  final _waitlistSizeCtrl = TextEditingController(text: '0');
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();

  String _gender = 'mixed';
  DateTime? _startTime;
  DateTime? _endTime;
  bool _saveAsTemplate = false;

  final _fmt = DateFormat('MMM d, yyyy  HH:mm');

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _minAgeCtrl.dispose();
    _maxAgeCtrl.dispose();
    _maxPlayersCtrl.dispose();
    _waitlistSizeCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? DateTime.now().add(const Duration(hours: 1))
        : (_startTime ?? DateTime.now()).add(const Duration(hours: 2));

    final picked = await showOmniDateTimePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(minutes: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      is24HourMode: true,
      isShowSeconds: false,
      minutesInterval: 5,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
    );

    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
        _startCtrl.text = _fmt.format(picked);
        if (_endTime != null && _endTime!.isBefore(picked)) {
          _endTime = null;
          _endCtrl.clear();
        }
      } else {
        _endTime = picked;
        _endCtrl.text = _fmt.format(picked);
      }
    });
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null || _endTime == null) return;
    if (_endTime!.isBefore(_startTime!)) {
      showAppSnackbar(l.endTimeError);
      return;
    }

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    setState(() => _isSubmitting = true);

    try {
      if (_saveAsTemplate) {
        await ref.read(templatesRepositoryProvider).save(
            user.uid,
            SessionTemplate(
              id: '',
              title: _titleCtrl.text.trim(),
              location: _locationCtrl.text.trim(),
              gender: _gender,
              minAge: int.tryParse(_minAgeCtrl.text) ?? 0,
              maxAge: int.tryParse(_maxAgeCtrl.text) ?? 99,
              maxPlayers: int.tryParse(_maxPlayersCtrl.text) ?? 10,
              waitlistSize: int.tryParse(_waitlistSizeCtrl.text) ?? 0,
              createdAt: DateTime.now(),
            ));
      }

      final session = SessionModel(
        id: '',
        title: _titleCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        gender: _gender,
        minAge: int.tryParse(_minAgeCtrl.text) ?? 0,
        maxAge: int.tryParse(_maxAgeCtrl.text) ?? 99,
        startTime: _startTime!,
        endTime: _endTime!,
        maxPlayers: int.tryParse(_maxPlayersCtrl.text) ?? 10,
        waitlistSize: int.tryParse(_waitlistSizeCtrl.text) ?? 0,
        coachId: user.uid,
        attendeeIds: const [],
        createdAt: DateTime.now(),
      );

      await ref.read(sessionsRepositoryProvider).create(session);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnackbar(l.sessionCreated);
    } catch (_) {
      showAppSnackbar(l.unknownError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.createSession)),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 40),
        child: AppFadeIn(
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BrandedTextField(
                label: l.sessionTitle,
                hint: l.sessionTitleHint,
                controller: _titleCtrl,
                validator: (v) => Validators.required(v, l.requiredField),
              ),
              const SizedBox(height: 16),
              BrandedTextField(
                label: l.location,
                hint: l.locationHint,
                controller: _locationCtrl,
                validator: (v) => Validators.required(v, l.requiredField),
              ),
              const SizedBox(height: 24),

              // Gender selector
              Text(l.gender,
                  style: const TextStyle(
                      color: AppColors.gold, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _GenderOption(
                      label: l.male,
                      value: 'male',
                      selected: _gender == 'male',
                      onTap: () => setState(() => _gender = 'male')),
                  const SizedBox(width: 10),
                  _GenderOption(
                      label: l.female,
                      value: 'female',
                      selected: _gender == 'female',
                      onTap: () => setState(() => _gender = 'female')),
                  const SizedBox(width: 10),
                  _GenderOption(
                      label: l.genderMixed,
                      value: 'mixed',
                      selected: _gender == 'mixed',
                      onTap: () => setState(() => _gender = 'mixed')),
                ],
              ),
              const SizedBox(height: 24),

              // Age range
              Text(l.ageRange,
                  style: const TextStyle(
                      color: AppColors.gold, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: BrandedTextField(
                      label: l.minAge,
                      controller: _minAgeCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          Validators.required(v, l.requiredField),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BrandedTextField(
                      label: l.maxAge,
                      controller: _maxAgeCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          Validators.required(v, l.requiredField),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Max players + waitlist size
              Row(
                children: [
                  Expanded(
                    child: BrandedTextField(
                      label: l.maxPlayers,
                      controller: _maxPlayersCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          Validators.required(v, l.requiredField),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BrandedTextField(
                      label: l.waitlistSize,
                      controller: _waitlistSizeCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          Validators.required(v, l.requiredField),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Start time
              BrandedTextField(
                label: l.startTime,
                controller: _startCtrl,
                readOnly: true,
                onTap: () => _pickTime(isStart: true),
                suffixIcon:
                    const Icon(Icons.event_outlined, color: AppColors.grey),
                validator: (v) =>
                    (v == null || v.isEmpty) ? l.requiredField : null,
              ),
              const SizedBox(height: 16),

              // End time
              BrandedTextField(
                label: l.endTime,
                controller: _endCtrl,
                readOnly: true,
                onTap: () => _pickTime(isStart: false),
                suffixIcon:
                    const Icon(Icons.event_outlined, color: AppColors.grey),
                validator: (v) =>
                    (v == null || v.isEmpty) ? l.requiredField : null,
              ),
              const SizedBox(height: 24),

              CheckboxListTile(
                value: _saveAsTemplate,
                onChanged: (v) =>
                    setState(() => _saveAsTemplate = v ?? false),
                title: Text(l.saveAsTemplate,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                activeColor: AppColors.gold,
                checkColor: AppColors.navyBlue,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),

              BrandedButton(
                label: l.createSession,
                onPressed: _submit,
                isLoading: _isSubmitting,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _GenderOption(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold : AppColors.navyLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.grey,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.navyBlue : AppColors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
