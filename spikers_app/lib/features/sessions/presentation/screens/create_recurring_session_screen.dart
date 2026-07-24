import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/features/sessions/domain/entities/recurring_session_model.dart';
import 'package:spikers_app/core/widgets/animations.dart';
import 'package:spikers_app/core/widgets/app_choice_chips.dart';
import 'package:spikers_app/core/widgets/branded_button.dart';
import 'package:spikers_app/core/widgets/branded_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/sessions_providers.dart';
import '../widgets/coach_select_chips.dart';
import '../widgets/member_picker_sheet.dart';

class CreateRecurringSessionScreen extends ConsumerStatefulWidget {
  /// Non-null when editing an existing schedule.
  final RecurringSessionModel? editing;
  const CreateRecurringSessionScreen({super.key, this.editing});

  @override
  ConsumerState<CreateRecurringSessionScreen> createState() =>
      _CreateRecurringSessionScreenState();
}

class _CreateRecurringSessionScreenState
    extends ConsumerState<CreateRecurringSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _minAgeCtrl = TextEditingController(text: '16');
  final _maxAgeCtrl = TextEditingController(text: '40');
  final _maxPlayersCtrl = TextEditingController(text: '12');
  final _waitlistSizeCtrl = TextEditingController(text: '0');

  String _gender = 'mixed';
  final Set<String> _selectedCoachIds = {};
  bool _isCustom = false;
  final Set<String> _selectedMemberIds = {};
  final Set<int> _selectedDays = {};
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 0);
  late final TextEditingController _startTimeCtrl;
  late final TextEditingController _endTimeCtrl;
  bool _isSubmitting = false;

  RecurringSessionModel? _editing;

  @override
  void initState() {
    super.initState();
    final arg = widget.editing;
    if (arg != null) {
      _editing = arg;
      _titleCtrl.text = arg.title;
      _locationCtrl.text = arg.location;
      _gender = arg.gender;
      _minAgeCtrl.text = arg.minAge.toString();
      _maxAgeCtrl.text = arg.maxAge.toString();
      _maxPlayersCtrl.text = arg.maxPlayers.toString();
      _waitlistSizeCtrl.text = arg.waitlistSize.toString();
      _selectedCoachIds.addAll(arg.coachIds);
      _selectedMemberIds.addAll(arg.memberIds);
      _isCustom = arg.memberIds.isNotEmpty;
      _selectedDays.addAll(arg.recurrenceDays);
      _startTime = TimeOfDay(hour: arg.startHour, minute: arg.startMinute);
      _endTime = TimeOfDay(hour: arg.endHour, minute: arg.endMinute);
    }
    _startTimeCtrl = TextEditingController(text: _fmtTime(_startTime));
    _endTimeCtrl = TextEditingController(text: _fmtTime(_endTime));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _minAgeCtrl.dispose();
    _maxAgeCtrl.dispose();
    _maxPlayersCtrl.dispose();
    _waitlistSizeCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
        _startTimeCtrl.text = _fmtTime(picked);
      } else {
        _endTime = picked;
        _endTimeCtrl.text = _fmtTime(picked);
      }
    });
  }

  Future<void> _pickMembers() async {
    final picked =
        await showMemberPicker(context, initial: _selectedMemberIds);
    if (picked == null || !mounted) return;
    setState(() {
      _selectedMemberIds
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      showAppSnackbar(l.selectDays);
      return;
    }
    if (_isCustom && _selectedMemberIds.isEmpty) {
      showAppSnackbar(l.selectMembersError);
      return;
    }
    // End must be after start (same-day wall clock); the materializer schedules
    // both times on the session's date, so a cross-midnight range is invalid.
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      showAppSnackbar(l.endTimeError);
      return;
    }

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final repo = ref.read(recurringSessionsRepositoryProvider);
    setState(() => _isSubmitting = true);

    // Custom (members-only) sessions ignore gender/age; store a wide-open
    // audience and rely on memberIds for visibility.
    final gender = _isCustom ? 'mixed' : _gender;
    final minAge = _isCustom ? 0 : (int.tryParse(_minAgeCtrl.text) ?? 16);
    final maxAge = _isCustom ? 99 : (int.tryParse(_maxAgeCtrl.text) ?? 40);
    final memberIds = _isCustom ? _selectedMemberIds.toList() : const <String>[];
    final coachIds = _selectedCoachIds.toList();

    try {
      if (_editing != null) {
        await repo.edit(_editing!.id, {
          'title': _titleCtrl.text.trim(),
          'location': _locationCtrl.text.trim(),
          'gender': gender,
          'minAge': minAge,
          'maxAge': maxAge,
          'maxPlayers': int.tryParse(_maxPlayersCtrl.text) ?? 12,
          'waitlistSize': int.tryParse(_waitlistSizeCtrl.text) ?? 0,
          'coachIds': coachIds,
          'memberIds': memberIds,
          'recurrenceDays': _selectedDays.toList()..sort(),
          'startHour': _startTime.hour,
          'startMinute': _startTime.minute,
          'endHour': _endTime.hour,
          'endMinute': _endTime.minute,
        });
        if (!mounted) return;
        Navigator.of(context).pop();
        showAppSnackbar(l.recurringUpdated,
            duration: const Duration(seconds: 2));
      } else {
        final model = RecurringSessionModel(
          id: '',
          coachId: user.uid,
          title: _titleCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          gender: gender,
          minAge: minAge,
          maxAge: maxAge,
          maxPlayers: int.tryParse(_maxPlayersCtrl.text) ?? 12,
          waitlistSize: int.tryParse(_waitlistSizeCtrl.text) ?? 0,
          coachIds: coachIds,
          memberIds: memberIds,
          recurrenceDays: _selectedDays.toList()..sort(),
          startHour: _startTime.hour,
          startMinute: _startTime.minute,
          endHour: _endTime.hour,
          endMinute: _endTime.minute,
          createdAt: DateTime.now(),
        );
        await repo.create(model);
        if (!mounted) return;
        Navigator.of(context).pop();
        showAppSnackbar(l.recurringCreated,
            duration: const Duration(seconds: 2));
      }
    } catch (_) {
      showAppSnackbar(l.errorOccurred);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final dayLabels = [l.sun, l.mon, l.tue, l.wed, l.thu, l.fri, l.sat];
    final isEditing = _editing != null;

    return Scaffold(
      appBar:
          AppBar(title: Text(isEditing ? l.editRecurring : l.createRecurring)),
      // SafeArea keeps the bottom CTA above the Android gesture bar.
      body: SafeArea(
        child: SingleChildScrollView(
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

              // Available coaches
              Text(l.availableCoaches.toUpperCase(),
                  style: AppTextStyles.eyebrow),
              const SizedBox(height: 8),
              CoachSelectChips(
                selectedIds: _selectedCoachIds,
                onToggle: (uid) => setState(() {
                  if (!_selectedCoachIds.add(uid)) {
                    _selectedCoachIds.remove(uid);
                  }
                }),
              ),
              const SizedBox(height: 24),

              // Custom (members-only) session
              SwitchListTile(
                value: _isCustom,
                onChanged: (v) => setState(() => _isCustom = v),
                title: Text(l.customSession,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(l.customSessionSubtitle,
                    style:
                        const TextStyle(color: AppColors.grey, fontSize: 12)),
                activeThumbColor: AppColors.gold,
                contentPadding: EdgeInsets.zero,
              ),
              if (_isCustom) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickMembers,
                  icon: const Icon(Icons.group_add_outlined,
                      color: AppColors.gold),
                  label: Text(
                    _selectedMemberIds.isEmpty
                        ? l.chooseMembers
                        : l.membersSelected(_selectedMemberIds.length),
                    style: const TextStyle(color: AppColors.gold),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: AppColors.gold),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              if (!_isCustom) ...[
                // Gender selector
                Text(l.gender.toUpperCase(), style: AppTextStyles.eyebrow),
                const SizedBox(height: 8),
                AppChoiceChips<String>(
                  value: _gender,
                  expanded: true,
                  onSelected: (v) => setState(() => _gender = v),
                  options: [
                    AppChoiceChipOption(value: 'male', label: l.male),
                    AppChoiceChipOption(value: 'female', label: l.female),
                    AppChoiceChipOption(value: 'mixed', label: l.genderMixed),
                  ],
                ),
                const SizedBox(height: 24),

                // Age range
                Text(l.ageRange.toUpperCase(), style: AppTextStyles.eyebrow),
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
              ],

              // Max players + waitlist
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
              const SizedBox(height: 24),

              // Day-of-week multi-select
              Text(l.recurrenceDays.toUpperCase(),
                  style: AppTextStyles.eyebrow),
              const SizedBox(height: 8),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: List.generate(7, (d) {
                  final active = _selectedDays.contains(d);
                  return AppChoiceChip(
                    label: dayLabels[d],
                    selected: active,
                    onTap: () => setState(() {
                      if (active) {
                        _selectedDays.remove(d);
                      } else {
                        _selectedDays.add(d);
                      }
                    }),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Time pickers — the two fields carry their own persistent
              // labels, so no section header is needed.
              Row(
                children: [
                  Expanded(
                    child: BrandedTextField(
                      label: l.startTime,
                      controller: _startTimeCtrl,
                      readOnly: true,
                      onTap: () => _pickTime(isStart: true),
                      suffixIcon: const Icon(Icons.access_time,
                          color: AppColors.grey, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: BrandedTextField(
                      label: l.endTime,
                      controller: _endTimeCtrl,
                      readOnly: true,
                      onTap: () => _pickTime(isStart: false),
                      suffixIcon: const Icon(Icons.access_time,
                          color: AppColors.grey, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              BrandedButton(
                label: isEditing ? l.save : l.createRecurring,
                onPressed: _submit,
                isLoading: _isSubmitting,
              ),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }
}
