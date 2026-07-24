import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import 'package:spikers_app/core/widgets/animations.dart';
import 'package:spikers_app/core/widgets/app_choice_chips.dart';
import 'package:spikers_app/core/widgets/branded_button.dart';
import 'package:spikers_app/core/widgets/branded_text_field.dart';
import 'package:spikers_app/features/sessions/domain/entities/player_group_model.dart';
import 'package:spikers_app/features/sessions/domain/player_group_selection.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../players/presentation/providers/players_providers.dart';
import '../providers/sessions_providers.dart';
import '../widgets/coach_select_chips.dart';
import '../widgets/member_picker_sheet.dart';
import '../widgets/player_group_actions.dart';
import '../widgets/player_group_rail.dart';
import '../widgets/session_art_picker.dart';
import '../../../../core/theme/app_spacing.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  ConsumerState<CreateSessionScreen> createState() =>
      _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController(text: 'Frer School');
  final _minAgeCtrl = TextEditingController(text: '16');
  final _maxAgeCtrl = TextEditingController(text: '40');
  final _maxPlayersCtrl = TextEditingController(text: '12');
  final _waitlistSizeCtrl = TextEditingController(text: '0');
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();

  String _gender = 'mixed';
  DateTime? _startTime;
  DateTime? _endTime;

  final Set<String> _selectedCoachIds = {};
  bool _isCustom = false;
  final Set<String> _selectedMemberIds = {};

  // Groups the coach has explicitly applied — the rail's gold-highlight state.
  // Tracked, not derived from the member set, so an overlapping group never
  // lights up just because its members are covered.
  final Set<String> _appliedGroupIds = {};

  // Admin-only testing controls. [_notify] off creates the session silently
  // (no push); [_designIndex] pins a specific card art (null = random).
  bool _notify = true;
  int? _designIndex;

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

  Future<void> _pickMembers() async {
    final picked =
        await showMemberPicker(context, initial: _selectedMemberIds);
    if (picked == null || !mounted) return;
    final groups = ref.read(playerGroupsProvider).valueOrNull ?? const [];
    final validUids =
        ref.read(playersProvider).valueOrNull?.map((p) => p.uid).toSet();
    setState(() {
      _selectedMemberIds
        ..clear()
        ..addAll(picked);
      // A manual edit in the picker may have broken a group's coverage — drop
      // any applied group no longer fully selected (never adds one).
      _syncAppliedGroups(groups, validUids);
    });
  }

  /// Toggles a saved group in/out of the selection, updating both the member
  /// set and the applied-group highlight. [validUids] drops members who no
  /// longer exist (null while the roster loads).
  void _applyGroup(
      PlayerGroup group, List<PlayerGroup> groups, Set<String>? validUids) {
    final result = toggleGroup(
      group: group,
      allGroups: groups,
      selected: _selectedMemberIds,
      appliedGroupIds: _appliedGroupIds,
      validUids: validUids,
    );
    setState(() {
      _selectedMemberIds
        ..clear()
        ..addAll(result.selected);
      _appliedGroupIds
        ..clear()
        ..addAll(result.appliedGroupIds);
    });
  }

  void _syncAppliedGroups(
      List<PlayerGroup> groups, Set<String>? validUids) {
    final reconciled = reconcileAppliedGroups(
      allGroups: groups,
      appliedGroupIds: _appliedGroupIds,
      selected: _selectedMemberIds,
      validUids: validUids,
    );
    _appliedGroupIds
      ..clear()
      ..addAll(reconciled);
  }

  /// Opens the member picker seeded with [group]'s current roster and saves the
  /// edited selection back to the group.
  Future<void> _editGroupMembers(PlayerGroup group) async {
    final updated =
        await showMemberPicker(context, initial: group.memberIds.toSet());
    if (updated == null || !mounted) return;
    await saveGroupMembers(context, ref, group, updated);
  }

  /// The "Quick groups" rail — a one-tap way to fill the roster from a saved
  /// group. Hidden until the coach has saved at least one (first group is
  /// created from the member picker's "Save as group" action).
  Widget _quickGroups(AppLocalizations l) {
    final groups = ref.watch(playerGroupsProvider).valueOrNull ?? const [];
    if (groups.isEmpty) return const SizedBox.shrink();
    final players = ref.watch(playersProvider).valueOrNull;
    final validUids = players?.map((p) => p.uid).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(l.quickGroups.toUpperCase(), style: AppTextStyles.eyebrow),
        const SizedBox(height: 8),
        PlayerGroupRail(
          groups: groups,
          appliedGroupIds: _appliedGroupIds,
          onApply: (g) => _applyGroup(g, groups, validUids),
          onManage: (g) => manageGroup(context, ref, g,
              onEditMembers: () => _editGroupMembers(g)),
          onNew: _pickMembers,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null || _endTime == null) return;
    if (_endTime!.isBefore(_startTime!)) {
      showAppSnackbar(l.endTimeError);
      return;
    }
    if (_isCustom && _selectedMemberIds.isEmpty) {
      showAppSnackbar(l.selectMembersError);
      return;
    }

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    // The silent-create and art-pin controls are admin-only; ignore any state
    // for everyone else so the standard notify + random-art path is unchanged.
    final isAdmin = ref.read(isAdminProvider);
    final silent = isAdmin && !_notify;
    final designIndex = isAdmin ? _designIndex : null;

    setState(() => _isSubmitting = true);

    // Custom (members-only) sessions ignore gender/age; store a wide-open
    // audience so they pass the server-side gender query + FCM validation,
    // and rely on memberIds for visibility.
    final gender = _isCustom ? 'mixed' : _gender;
    final minAge = _isCustom ? 0 : (int.tryParse(_minAgeCtrl.text) ?? 0);
    final maxAge = _isCustom ? 99 : (int.tryParse(_maxAgeCtrl.text) ?? 99);

    try {
      final session = SessionModel(
        id: '',
        title: _titleCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        gender: gender,
        minAge: minAge,
        maxAge: maxAge,
        startTime: _startTime!,
        endTime: _endTime!,
        maxPlayers: int.tryParse(_maxPlayersCtrl.text) ?? 10,
        waitlistSize: int.tryParse(_waitlistSizeCtrl.text) ?? 0,
        coachId: user.uid,
        coachIds: _selectedCoachIds.toList(),
        memberIds: _isCustom ? _selectedMemberIds.toList() : const [],
        attendeeIds: const [],
        createdAt: DateTime.now(),
        // A silent session is written already-notified so the onSessionCreated
        // Cloud Function skips the create push; the persisted [silent] flag also
        // makes cancelSession skip its cancellation push for the same session.
        notified: silent,
        silent: silent,
      );

      await ref
          .read(sessionsRepositoryProvider)
          .create(session, designIndex: designIndex);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnackbar(l.sessionCreated);
    } catch (_) {
      showAppSnackbar(l.unknownError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _adminTestingSection(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.navyElevated),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined,
                  size: 16, color: AppColors.gold),
              const SizedBox(width: AppSpacing.xs),
              Text(l.adminTesting.toUpperCase(), style: AppTextStyles.eyebrow),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Notify toggle — off means the session is created silently.
          SwitchListTile(
            value: _notify,
            onChanged: (v) => setState(() => _notify = v),
            title: Text(l.notifyOnCreate,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(l.notifyOnCreateSubtitle,
                style: const TextStyle(color: AppColors.grey, fontSize: 12)),
            activeThumbColor: AppColors.gold,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l.sessionArt.toUpperCase(), style: AppTextStyles.sectionHeader),
          const SizedBox(height: AppSpacing.sm),
          SessionArtPicker(
            value: _designIndex,
            onChanged: (v) => setState(() => _designIndex = v),
            randomLabel: l.sessionArtRandom,
            cardSemanticLabel: (n) => l.sessionArtCard(n),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isAdmin = ref.watch(isAdminProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.createSession)),
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
                _quickGroups(l),
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

              // Admin-only testing controls: create a session silently and/or
              // pin a specific card art, for trying out new art and session
              // tweaks without notifying players, coaches or other admins.
              if (isAdmin) ...[
                _adminTestingSection(l),
                const SizedBox(height: 24),
              ],

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
      ),
    );
  }
}
