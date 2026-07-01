import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/widgets/injured_icon.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/media_permissions.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/core/widgets/confirm_dialog.dart';
import 'package:spikers_app/core/widgets/edit_body_metrics_dialog.dart';
import 'package:spikers_app/core/widgets/profile_info.dart';
import 'package:spikers_app/core/widgets/set_profile_basics_dialog.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key, this.revealGeneration = 0});

  /// Bumped by the home shell each time this tab becomes visible; re-mounts the
  /// body below so the staggered entrance replays on every visit.
  final int revealGeneration;

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  bool _uploading = false;
  bool _deleting = false;

  /// Confirms, then permanently deletes the user's own account and returns to
  /// login. Keeps the user signed in (with a snackbar) if the backend fails.
  Future<void> _deleteAccount(AppLocalizations l) async {
    if (_deleting) return;
    final confirmed = await showDeleteConfirm(
      context,
      title: l.deleteMyAccountTitle,
      message: l.deleteMyAccountConfirm,
      confirmLabel: l.delete,
      cancelLabel: l.cancel,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(authRepositoryProvider).deleteOwnAccount();
      appRouter.go(Routes.login);
    } catch (_) {
      if (mounted) setState(() => _deleting = false);
      showAppSnackbar(l.deleteMyAccountError);
    }
  }

  void _showAvatarPicker(AppLocalizations l) {
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
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.gold,
              ),
              title: Text(l.pickFromGallery),
              onTap: () {
                Navigator.of(context).pop();
                _pickAndUpload(ImageSource.gallery, l);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.gold,
              ),
              title: Text(l.takePhoto),
              onTap: () {
                Navigator.of(context).pop();
                _pickAndUpload(ImageSource.camera, l);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source, AppLocalizations l) async {
    // Camera capture needs a runtime permission; gallery goes through the
    // Android Photo Picker / iOS PHPicker, which require none.
    if (source == ImageSource.camera) {
      final granted = await ensureCameraPermission(context, l);
      if (!granted || !mounted) return;
    }
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      await ref.read(authRepositoryProvider).updateProfilePhoto(file);
      showAppSnackbar(l.photoUpdated);
    } catch (_) {
      showAppSnackbar(l.unknownError);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = ref.watch(currentUserProvider).value;
    final email = ref.watch(authRepositoryProvider).currentEmail;

    if (user == null) return const SizedBox.shrink();

    return KeyedSubtree(
      key: ValueKey(widget.revealGeneration),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          children:
              [
                    const SizedBox(height: 16),
                    _Avatar(
                      name: user.name,
                      photoUrl: user.photoUrl,
                      isUploading: _uploading,
                      onTap: () => _showAvatarPicker(l),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (user.injured) ...[
                          const SizedBox(width: 8),
                          const InjuredIcon(size: 22),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        color: AppColors.grey,
                        fontSize: 14,
                      ),
                    ),
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
                    if (user.gender == null || user.dateOfBirth == null) ...[
                      const SizedBox(height: 12),
                      _CompleteProfileCard(
                        l: l,
                        onTap: () => showSetProfileBasicsDialog(context, user),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _PaymentHistoryRow(l: l, userId: user.uid),
                    const SizedBox(height: 16),
                    _LanguageToggle(l: l),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => signOutToLogin(ref),
                        icon: const Icon(
                          Icons.logout,
                          color: AppColors.errorRed,
                        ),
                        label: Text(
                          l.signOut,
                          style: const TextStyle(color: AppColors.errorRed),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.errorRed),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _deleting ? null : () => _deleteAccount(l),
                      child: _deleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.errorRed,
                              ),
                            )
                          : Text(
                              l.deleteMyAccountTitle,
                              style: const TextStyle(
                                color: AppColors.grey,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ]
                  .animate(interval: AppMotion.stagger)
                  .fadeIn(duration: AppMotion.normal, curve: AppMotion.enter)
                  .slideY(begin: 0.12, end: 0, curve: AppMotion.enter),
        ),
      ),
    );
  }
}

/// Shown on the owner's profile when gender and/or date of birth are not set
/// yet. Opens the set-once dialog. Disappears once both are filled in.
class _CompleteProfileCard extends StatelessWidget {
  final AppLocalizations l;
  final VoidCallback onTap;
  const _CompleteProfileCard({required this.l, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold),
          ),
          child: Row(
            children: [
              const Icon(Icons.badge_outlined, size: 18, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.completeProfile,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool isUploading;
  final VoidCallback? onTap;
  const _Avatar({
    required this.name,
    this.photoUrl,
    this.isUploading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();

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
                      color: AppColors.navyBlue,
                    ),
                  )
                : null,
          ),
          if (isUploading)
            Container(
              width: 128,
              height: 128,
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.gold,
                ),
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
                child: const Icon(
                  Icons.camera_alt,
                  size: 14,
                  color: AppColors.gold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens the signed-in user's own payment history log.
class _PaymentHistoryRow extends StatelessWidget {
  final AppLocalizations l;
  final String userId;
  const _PaymentHistoryRow({required this.l, required this.userId});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('${Routes.paymentHistory}?uid=$userId'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.paymentHistory,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageToggle extends ConsumerWidget {
  final AppLocalizations l;
  const _LanguageToggle({required this.l});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    return InkWell(
      onTap: () => ref.read(localeProvider.notifier).toggle(),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.language_outlined, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.switchLanguage,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              size: 16,
              color: AppColors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
