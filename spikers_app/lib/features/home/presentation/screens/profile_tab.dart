import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/utils/attendance_tiers.dart';
import '../../../../core/utils/endorsement_level.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/celebration.dart';
import '../../../../core/widgets/injured_icon.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/media_permissions.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/core/widgets/branded_text_field.dart';
import 'package:spikers_app/core/widgets/confirm_dialog.dart';
import 'package:spikers_app/core/widgets/edit_body_metrics_dialog.dart';
import 'package:spikers_app/core/widgets/floating_nav_bar.dart';
import 'package:spikers_app/core/widgets/membership_chip.dart';
import 'package:spikers_app/core/widgets/profile_info.dart';
import 'package:spikers_app/core/widgets/ringed_avatar.dart';
import 'package:spikers_app/core/widgets/set_profile_basics_dialog.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/achievements_card.dart';
import '../widgets/profile_stat_cards.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  bool _uploading = false;
  bool _deleting = false;

  /// Compares the freshly fetched attendance [count] with the last count this
  /// device saw (SharedPreferences) and celebrates when a tier boundary was
  /// crossed since. The stored value is updated every time so each milestone
  /// fires exactly once per device; the first sighting only records a baseline
  /// (no celebration on a fresh install).
  Future<void> _checkMilestone(
    String uid,
    int count,
    AppLocalizations l,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'last_seen_attendance_$uid';
    final previous = prefs.getInt(key);
    await prefs.setInt(key, count);
    if (previous == null) return;

    final tier = AttendanceTiers.crossedTier(previous, count);
    if (tier == null || !mounted) return;
    HapticFeedback.mediumImpact();
    showCelebration(context, badgeAsset: AppAssets.gamesPlayedBadges[tier]);
    showAppSnackbar('🎉 ${l.milestoneUnlocked(count, tierLabel(l, tier))}');
  }

  /// Endorsement-level twin of [_checkMilestone]: celebrates when the lifetime
  /// endorsement [count] climbs across a level boundary since this device last
  /// saw it. Same one-shot-per-device baseline behaviour, keyed separately so
  /// it can't collide with the games-played milestone.
  Future<void> _checkEndorsementMilestone(
    String uid,
    int count,
    AppLocalizations l,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'last_seen_endorsements_$uid';
    final previous = prefs.getInt(key);
    await prefs.setInt(key, count);
    if (previous == null) return;

    final level = crossedEndorsementLevel(previous, count);
    if (level == null || !mounted) return;
    HapticFeedback.mediumImpact();
    showCelebration(
      context,
      badgeAsset: AppAssets.endorsementBadges[level - 1],
    );
    showAppSnackbar(
      '🎉 ${l.endorsementMilestoneUnlocked(count, l.endorsementLevelLabel(level))}',
    );
  }

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

  Future<void> _showCoachKeyDialog(AppLocalizations l) async {
    final promoted = await showDialog<bool>(
      context: context,
      builder: (_) => const _CoachKeyDialog(),
    );
    if (promoted != true || !mounted) return;
    // The user doc listener flips the role to coach; celebrate the unlock.
    HapticFeedback.mediumImpact();
    showCelebration(context, icon: Icons.sports, grand: true, dim: true);
    showAppSnackbar('🎉 ${l.coachPromotedSnack}');
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

    // Milestone watch: fires when the games-played fetch lands (app open /
    // profile revisit). The prefs baseline inside keeps it one-shot per tier.
    ref.listen(myAttendanceCountProvider(user.uid), (_, next) {
      final count = next.value;
      if (count != null) _checkMilestone(user.uid, count, l);
    });
    // Same one-shot promotion burst for the endorsement level.
    ref.listen(myEndorsementCountProvider(user.uid), (_, next) {
      final count = next.value;
      if (count != null) _checkEndorsementMilestone(user.uid, count, l);
    });

    // The hero avatar docks the tier badge once the attendance count lands
    // (mirroring the games-played card's coach-with-zero hiding rule).
    final attendance = ref.watch(myAttendanceCountProvider(user.uid)).value;
    final showTierBadge =
        attendance != null && !(user.isCoach && attendance == 0);
    final tier = AttendanceTiers.tierIndex(attendance ?? 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        FloatingNavBar.scrollClearance,
      ),
      child: Column(
        children:
            [
                  const SizedBox(height: 8),
                  _HeroAvatar(
                    user: user,
                    badgeAsset: showTierBadge
                        ? AppAssets.gamesPlayedBadges[tier]
                        : null,
                    badgeLabel: showTierBadge ? tierLabel(l, tier) : null,
                    isUploading: _uploading,
                    onTap: () => _showAvatarPicker(l),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (user.injured) ...[
                        const SizedBox(width: 8),
                        const InjuredIcon(size: 22),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: const TextStyle(color: AppColors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ProfileRoleBadge(isCoach: user.isCoach, l: l),
                      _MemberSinceChip(year: user.createdAt.year, l: l),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GamesPlayedCard(uid: user.uid, isCoach: user.isCoach, l: l),
                  EndorsementsCard(uid: user.uid, isCoach: user.isCoach, l: l),
                  AchievementsCard(uid: user.uid, l: l),
                  const SizedBox(height: 24),
                  _SectionHeader(label: l.sectionDetails),
                  const SizedBox(height: 10),
                  ProfileStatsRow(
                    user: user,
                    l: l,
                    onEdit: () => showEditBodyMetricsDialog(context, user),
                  ),
                  const SizedBox(height: 12),
                  ProfileInfoCard(user: user, l: l),
                  if (user.gender == null || user.dateOfBirth == null) ...[
                    const SizedBox(height: 12),
                    _CompleteProfileCard(
                      l: l,
                      onTap: () => showSetProfileBasicsDialog(context, user),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _SectionHeader(label: l.sectionAccount),
                  const SizedBox(height: 10),
                  _AccountCard(l: l, user: user),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => signOutToLogin(ref),
                      icon: const Icon(Icons.logout, color: AppColors.errorRed),
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
                  // Deliberately low-key: the coach key is handed out
                  // in person, so this shouldn't read as a feature to
                  // regular players — just an unlock for those who have one.
                  if (!user.isCoach)
                    TextButton(
                      onPressed: () => _showCoachKeyDialog(l),
                      child: Text(
                        l.haveCoachKey,
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
    );
  }
}

/// Quiet uppercase divider between the profile's zones — gamified cards above,
/// personal details and account plumbing below.
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Text(
          label.toUpperCase(),
          // ≥75% white keeps this quiet header above WCAG AA on the navy
          // gradient (Premium Pass Phase 7 contrast pass).
          style: TextStyle(
            color: AppColors.white.withValues(alpha: 0.75),
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

/// The owner's hero avatar: ringed tier avatar plus the photo-upload
/// affordances (camera chip docked bottom-start so it never collides with the
/// tier badge on the bottom-end corner, and a dimming spinner while a new
/// photo uploads).
class _HeroAvatar extends StatelessWidget {
  final UserModel user;
  final String? badgeAsset;
  final String? badgeLabel;
  final bool isUploading;
  final VoidCallback? onTap;
  const _HeroAvatar({
    required this.user,
    this.badgeAsset,
    this.badgeLabel,
    this.isUploading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: isUploading ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RingedAvatar(
            name: user.name,
            photoUrl: user.photoUrl,
            radius: 64,
            badgeAsset: badgeAsset,
            badgeLabel: badgeLabel,
          ),
          if (isUploading)
            // 140 = inner avatar (128) + ring and gap padding (2 × 6).
            Container(
              width: 140,
              height: 140,
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
            PositionedDirectional(
              bottom: 2,
              start: 2,
              child: Container(
                padding: const EdgeInsets.all(6),
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

/// Quiet "member since {year}" chip next to the role badge.
class _MemberSinceChip extends StatelessWidget {
  final int year;
  final AppLocalizations l;
  const _MemberSinceChip({required this.year, required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            size: 14,
            color: AppColors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            l.memberSince('$year'),
            style: const TextStyle(
              color: AppColors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                color: AppColors.gold,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Account plumbing grouped into one card: payment history (with the member's
/// live membership status) and the language toggle, separated by a hairline —
/// so utility rows stop competing with the stat cards above for attention.
class _AccountCard extends ConsumerWidget {
  final AppLocalizations l;
  final UserModel user;
  const _AccountCard({required this.l, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = ref.watch(localeProvider).languageCode == 'ar';
    final chevron = Icon(
      Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_left
          : Icons.chevron_right,
      size: 20,
      color: AppColors.white.withValues(alpha: 0.30),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: profileCardChrome(),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            InkWell(
              onTap: () =>
                  context.push('${Routes.paymentHistory}?uid=${user.uid}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.paymentHistory,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (!user.isCoach) ...[
                      MembershipChip(
                        isPaid: user.isPaid,
                        daysLeft: user.paymentDaysLeft,
                        isLifetime: user.lifetimeMember,
                      ),
                      const SizedBox(width: 8),
                    ],
                    chevron,
                  ],
                ),
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsetsDirectional.only(start: 52, end: 16),
              color: AppColors.white.withValues(alpha: 0.06),
            ),
            InkWell(
              onTap: () => ref.read(localeProvider.notifier).toggle(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
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
                    // The language you'd switch TO — clearer than an arrow.
                    Text(
                      isArabic ? 'English' : 'العربية',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    chevron,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coach-key entry: validates via the rate-limited backend callable and pops
/// `true` on promotion. Errors render inline so a typo doesn't lose the input.
class _CoachKeyDialog extends ConsumerStatefulWidget {
  const _CoachKeyDialog();

  @override
  ConsumerState<_CoachKeyDialog> createState() => _CoachKeyDialogState();
}

class _CoachKeyDialogState extends ConsumerState<_CoachKeyDialog> {
  final _keyCtrl = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _errorText = l.requiredField);
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    final result = await ref.read(authRepositoryProvider).promoteToCoach(key);
    if (!mounted) return;
    switch (result) {
      case CoachPromotion.promoted:
        Navigator.of(context).pop(true);
      case CoachPromotion.invalidKey:
        setState(() {
          _submitting = false;
          _errorText = l.invalidCoachKey;
        });
      case CoachPromotion.networkError:
        setState(() {
          _submitting = false;
          _errorText = l.networkError;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.navyLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l.coachKey, style: const TextStyle(color: AppColors.white)),
      content: BrandedTextField(
        label: l.coachKey,
        hint: l.coachKeyHint,
        controller: _keyCtrl,
        autofocus: true,
        enabled: !_submitting,
        onSubmitted: (_) => _submit(),
        errorText: _errorText,
        // The dialog surface is navyLight — use the darker navy fill so the
        // field stays visible.
        fillColor: AppColors.navyBlue,
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(l.cancel, style: const TextStyle(color: AppColors.grey)),
        ),
        TextButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                )
              : Text(
                  l.save,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}
