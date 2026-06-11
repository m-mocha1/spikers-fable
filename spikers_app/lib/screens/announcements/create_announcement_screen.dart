import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/announcement_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/announcement_model.dart';
import '../widgets/branded_button.dart';
import '../widgets/branded_text_field.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _isSubmitting = false;
  AnnouncementModel? _existing;

  @override
  void initState() {
    super.initState();
    final arg = Get.arguments;
    if (arg is AnnouncementModel) {
      _existing = arg;
      _titleCtrl.text = arg.title;
      _bodyCtrl.text = arg.body;
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
    final controller = Get.find<AnnouncementController>();
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    try {
      if (_existing != null) {
        await controller.edit(id: _existing!.id, title: title, body: body);
      } else {
        await controller.create(title: title, body: body);
      }
      if (!mounted) return;
      Get.back();
      Get.snackbar(
        '',
        _existing != null ? l.announcementUpdated : l.announcementCreated,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (_) {
      if (!mounted) return;
      Get.snackbar('', l.errorOccurred,
          snackPosition: SnackPosition.BOTTOM);
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
                BrandedButton(
                  label: l.save,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
