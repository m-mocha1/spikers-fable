import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/title_case.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_template_model.dart';
import 'package:spikers_app/core/widgets/branded_button.dart';
import 'package:spikers_app/core/widgets/branded_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/sessions_providers.dart';

class QuickSessionScreen extends ConsumerStatefulWidget {
  const QuickSessionScreen({super.key});

  @override
  ConsumerState<QuickSessionScreen> createState() =>
      _QuickSessionScreenState();
}

class _QuickSessionScreenState extends ConsumerState<QuickSessionScreen> {
  final _fmt = DateFormat('MMM d, yyyy  HH:mm');
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();

  SessionTemplate? _selected;
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isSubmitting = false;

  @override
  void dispose() {
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
    if (_selected == null || _startTime == null || _endTime == null) return;
    if (_endTime!.isBefore(_startTime!)) {
      showAppSnackbar(l.endTimeError);
      return;
    }
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    setState(() => _isSubmitting = true);

    final session = SessionModel(
      id: '',
      title: _selected!.title,
      location: _selected!.location,
      gender: _selected!.gender,
      minAge: _selected!.minAge,
      maxAge: _selected!.maxAge,
      startTime: _startTime!,
      endTime: _endTime!,
      maxPlayers: _selected!.maxPlayers,
      waitlistSize: _selected!.waitlistSize,
      coachId: user.uid,
      attendeeIds: const [],
      createdAt: DateTime.now(),
    );

    try {
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
    final templatesAsync = ref.watch(templatesProvider);
    final uid = ref.watch(currentUserProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(l.quickSession)),
      body: templatesAsync.when(
        loading: () => const ListShimmer(itemHeight: 96),
        error: (e, _) =>
            ErrorView(onRetry: () => ref.invalidate(templatesProvider)),
        data: (templates) {
          if (templates.isEmpty) {
            return EmptyStateView(
              icon: Icons.bookmark_border_outlined,
              title: l.noTemplates,
              subtitle: l.noTemplatesDesc,
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
                  itemCount: templates.length,
                  itemBuilder: (_, i) => AppStaggeredItem(
                    index: i,
                    child: _TemplateCard(
                      template: templates[i],
                      selected: _selected?.id == templates[i].id,
                      onTap: () => setState(() => _selected = templates[i]),
                      onDelete: uid == null
                          ? () {}
                          : () => ref
                              .read(templatesRepositoryProvider)
                              .delete(uid, templates[i].id),
                    ),
                  ),
                ),
              ),
              _buildTimeSection(l),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeSection(AppLocalizations l) {
    final canCreate =
        _selected != null && _startTime != null && _endTime != null;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // SafeArea keeps the Create CTA above the Android gesture bar while the
      // panel background still reaches the screen edge.
      child: SafeArea(
        top: false,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: BrandedTextField(
                  label: l.startTime,
                  controller: _startCtrl,
                  readOnly: true,
                  onTap: () => _pickTime(isStart: true),
                  suffixIcon: const Icon(Icons.event_outlined,
                      color: AppColors.grey, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BrandedTextField(
                  label: l.endTime,
                  controller: _endCtrl,
                  readOnly: true,
                  onTap: () => _pickTime(isStart: false),
                  suffixIcon: const Icon(Icons.event_outlined,
                      color: AppColors.grey, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BrandedButton(
            label: l.createSession,
            onPressed: canCreate ? _submit : null,
            isLoading: _isSubmitting,
          ),
        ],
      ),
      ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final SessionTemplate template;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.08)
              : AppColors.navyLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.gold : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.grey),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(template.location.toTitleCase(),
                            style: const TextStyle(
                                color: AppColors.grey, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${template.minAge}–${template.maxAge} yrs  ·  ${template.maxPlayers} players',
                    style:
                        const TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 4),
                child:
                    Icon(Icons.check_circle, color: AppColors.gold, size: 20),
              ),
            IconButton(
              tooltip: AppLocalizations.of(context)!.delete,
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.grey, size: 20),
              onPressed: onDelete,
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}
