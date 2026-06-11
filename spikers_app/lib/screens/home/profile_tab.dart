import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../controller/auth_controller.dart';
import '../../controller/locale_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/edit_body_metrics_dialog.dart';
import '../widgets/profile_info.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  static void _showAvatarPicker(
      BuildContext context, AppLocalizations l, AuthController auth) {
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
              leading:
                  const Icon(Icons.photo_library_outlined, color: AppColors.gold),
              title: Text(l.pickFromGallery),
              onTap: () {
                Get.back();
                _pickAndUpload(ImageSource.gallery, auth);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_outlined, color: AppColors.gold),
              title: Text(l.takePhoto),
              onTap: () {
                Get.back();
                _pickAndUpload(ImageSource.camera, auth);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static Future<void> _pickAndUpload(
      ImageSource source, AuthController auth) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (file != null) await auth.updateProfilePhoto(file);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final auth = Get.find<AuthController>();
    final locale = Get.find<LocaleController>();

    return Obx(() {
      final user = auth.currentUser.value;
      if (user == null) return const SizedBox.shrink();

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _Avatar(
              name: user.name,
              photoUrl: user.photoUrl,
              isUploading: auth.isLoading.value,
              onTap: () => _showAvatarPicker(context, l, auth),
            ),
            const SizedBox(height: 16),
            Text(user.name,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(auth.currentEmail,
                style:
                    const TextStyle(color: AppColors.grey, fontSize: 14)),
            const SizedBox(height: 12),
            ProfileRoleBadge(isCoach: user.isCoach, l: l),
            const SizedBox(height: 24),
            ProfileStatsRow(
              user: user,
              l: l,
              onEdit: () => showEditBodyMetricsDialog(context, user),
            ),
            const SizedBox(height: 16),
            ProfileInfoCard(user: user, l: l),
            const SizedBox(height: 24),
            _LanguageToggle(locale: locale, l: l),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: auth.signOut,
                icon: const Icon(Icons.logout, color: AppColors.errorRed),
                label: Text(l.signOut,
                    style:
                        const TextStyle(color: AppColors.errorRed)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.errorRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool isUploading;
  final VoidCallback? onTap;
  const _Avatar(
      {required this.name,
      this.photoUrl,
      this.isUploading = false,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();

    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 64,
            backgroundColor: AppColors.gold,
            backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                ? CachedNetworkImageProvider(photoUrl!)
                : null,
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? Text(
                    initials,
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyBlue),
                  )
                : null,
          ),
          if (isUploading)
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.gold),
              ),
            ),
          if (!isUploading)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.navyLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.navyBlue, width: 2),
                ),
                child: const Icon(Icons.camera_alt,
                    size: 14, color: AppColors.gold),
              ),
            ),
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final LocaleController locale;
  final AppLocalizations l;
  const _LanguageToggle({required this.locale, required this.l});

  @override
  Widget build(BuildContext context) {
    return Obx(() => InkWell(
          onTap: locale.toggle,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.navyLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.language_outlined, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l.switchLanguage,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Icon(
                  locale.isArabic
                      ? Icons.arrow_forward_ios
                      : Icons.arrow_back_ios,
                  size: 16,
                  color: AppColors.grey,
                ),
              ],
            ),
          ),
        ));
  }
}
