import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/app_choice_chips.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/core/widgets/branded_button.dart';
import 'package:spikers_app/core/widgets/branded_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/announcement.dart';
import '../providers/announcements_providers.dart';

class CreateAnnouncementScreen extends ConsumerStatefulWidget {
  /// Non-null when editing an existing announcement.
  final AnnouncementModel? existing;
  const CreateAnnouncementScreen({super.key, this.existing});

  @override
  ConsumerState<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState
    extends ConsumerState<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _isSubmitting = false;
  AnnouncementModel? _existing;
  String _audience = 'all';

  @override
  void initState() {
    super.initState();
    final arg = widget.existing;
    if (arg != null) {
      _existing = arg;
      _titleCtrl.text = arg.title;
      _bodyCtrl.text = arg.body;
      _audience = arg.audience;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(announcementsRepositoryProvider);
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    try {
      if (_existing != null) {
        await repo.edit(
            id: _existing!.id,
            title: title,
            body: body,
            audience: _audience);
      } else {
        final user = ref.read(currentUserProvider).value;
        if (user == null) return;
        await repo.create(
            title: title,
            body: body,
            authorId: user.uid,
            authorName: user.name,
            audience: _audience);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnackbar(
        _existing != null ? l.announcementUpdated : l.announcementCreated,
        duration: const Duration(seconds: 2),
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackbar(l.errorOccurred);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isEdit = _existing != null;
    return Scaffold(
      appBar: AppBar(
          title: Text(isEdit ? l.editAnnouncement : l.newAnnouncement)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BrandedTextField(
                  label: l.announcementTitle,
                  controller: _titleCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l.requiredField : null,
                ),
                const SizedBox(height: 16),
                BrandedTextField(
                  label: l.announcementBody,
                  controller: _bodyCtrl,
                  maxLines: 6,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l.requiredField : null,
                ),
                const SizedBox(height: 24),
                Text(l.audience.toUpperCase(), style: AppTextStyles.eyebrow),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppChoiceChips<String>(
                    value: _audience,
                    onSelected: (v) => setState(() => _audience = v),
                    options: [
                      AppChoiceChipOption(value: 'all', label: l.allGenders),
                      AppChoiceChipOption(value: 'male', label: l.male),
                      AppChoiceChipOption(value: 'female', label: l.female),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                BrandedButton(
                  // "Post" when composing — "Save" only makes sense when
                  // editing an existing announcement.
                  label: isEdit ? l.save : l.post,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ]
                  .animate(interval: AppMotion.stagger)
                  .fadeIn(duration: AppMotion.normal, curve: AppMotion.enter)
                  .slideY(begin: 0.15, end: 0, curve: AppMotion.enter),
            ),
          ),
        ),
      ),
    );
  }
}
