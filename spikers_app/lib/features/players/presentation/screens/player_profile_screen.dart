import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/injured_icon.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import 'package:spikers_app/core/widgets/profile_info.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/providers/profile_providers.dart';
import '../../../home/presentation/widgets/profile_stat_cards.dart';
import '../widgets/payment_confirm_dialog.dart';
import '../providers/players_providers.dart';

class PlayerProfileScreen extends ConsumerWidget {
  final String? userId;
  const PlayerProfileScreen({super.key, this.userId});

  Future<void> _confirmDeleteUser(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String name,
    AppLocalizations l,
  ) async {
    final confirmed = await showDeleteConfirm(
      context,
      title: l.deleteAccountTitle,
      message: l.deleteAccountConfirm(name),
      confirmLabel: l.delete,
      cancelLabel: l.cancel,
    );
    if (!confirmed) return;
    try {
      await ref.read(playersRepositoryProvider).deletePlayer(uid);
      showAppSnackbar(l.accountDeleted);
      if (context.mounted) context.pop();
    } catch (_) {
      showAppSnackbar(l.unknownError);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final userId = this.userId;

    if (userId == null || userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            l.unknownError,
            style: const TextStyle(color: AppColors.grey),
          ),
        ),
      );
    }

    // Non-staff viewers may only see another player's public reputation
    // (games played + endorsements) — the full /users doc is coach/owner-only
    // by Firestore rules, so we never even read it here. See _PublicPlayerView.
    final viewerIsCoach = ref.watch(isCoachProvider);
    if (!viewerIsCoach) {
      return _PublicPlayerView(userId: userId);
    }

    final userAsync = ref.watch(playerProvider(userId));

    return userAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(onRetry: () => ref.invalidate(playerProvider(userId))),
      ),
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyStateView(
              icon: Icons.person_off_outlined,
              title: l.noPlayers,
            ),
          );
        }

        final isCoach = ref.watch(isCoachProvider);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (isCoach)
                IconButton(
                  tooltip: l.delete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.errorRed,
                  ),
                  onPressed: () =>
                      _confirmDeleteUser(context, ref, user.uid, user.name, l),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children:
                  [
                        const SizedBox(height: 16),
                        _ReadOnlyAvatar(
                          name: user.name,
                          photoUrl: user.photoUrl,
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
                        const SizedBox(height: 12),
                        ProfileRoleBadge(isCoach: user.isCoach, l: l),
                        const SizedBox(height: 24),
                        GamesPlayedCard(
                          uid: user.uid,
                          isCoach: user.isCoach,
                          l: l,
                        ),
                        EndorsementsCard(
                          uid: user.uid,
                          isCoach: user.isCoach,
                          l: l,
                        ),
                        ProfileStatsRow(user: user, l: l),
                        const SizedBox(height: 16),
                        ProfileInfoCard(user: user, l: l),
                        if (!user.isCoach && !user.lifetimeMember) ...[
                          const SizedBox(height: 24),
                          _PaymentActionButton(user: user, l: l),
                        ],
                        if (!user.isCoach) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => context.push(
                                '${Routes.paymentHistory}?uid=${user.uid}',
                              ),
                              icon: const Icon(
                                Icons.receipt_long_outlined,
                                color: AppColors.gold,
                              ),
                              label: Text(
                                l.paymentHistory,
                                style: const TextStyle(color: AppColors.gold),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.gold),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ]
                      .animate(interval: AppMotion.stagger)
                      .fadeIn(
                        duration: AppMotion.normal,
                        curve: AppMotion.enter,
                      )
                      .slideY(begin: 0.12, end: 0, curve: AppMotion.enter),
            ),
          ),
        );
      },
    );
  }
}

class _ReadOnlyAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  const _ReadOnlyAvatar({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();

    return CircleAvatar(
      radius: 80,
      backgroundColor: AppColors.gold,
      backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
          ? CachedNetworkImageProvider(photoUrl!)
          : null,
      child: (photoUrl == null || photoUrl!.isEmpty)
          ? Text(
              initials,
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                color: AppColors.navyBlue,
              ),
            )
          : null,
    );
  }
}

/// The view a non-staff player sees when opening another player's profile:
/// avatar + name plus only the Games Played and Endorsements cards. All other
/// profile information stays hidden, and — critically — the private /users doc
/// is never read (it's coach/owner-only). Everything here is sourced from the
/// public mirror (users_public), readable by any verified user.
class _PublicPlayerView extends ConsumerWidget {
  final String userId;
  const _PublicPlayerView({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(myPublicProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          profileAsync.value?.name ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: profileAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          onRetry: () => ref.invalidate(myPublicProfileProvider(userId)),
        ),
        data: (profile) {
          if (profile == null) {
            return EmptyStateView(
              icon: Icons.person_off_outlined,
              title: l.noPlayers,
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children:
                  [
                        const SizedBox(height: 16),
                        _ReadOnlyAvatar(
                          name: profile.name,
                          photoUrl: profile.photoUrl,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          profile.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // isCoach: false — always render the cards for the viewed
                        // player (the coach-with-zero hiding rule doesn't apply here).
                        GamesPlayedCard(uid: userId, isCoach: false, l: l),
                        EndorsementsCard(uid: userId, isCoach: false, l: l),
                        const SizedBox(height: 16),
                      ]
                      .animate(interval: AppMotion.stagger)
                      .fadeIn(
                        duration: AppMotion.normal,
                        curve: AppMotion.enter,
                      )
                      .slideY(begin: 0.12, end: 0, curve: AppMotion.enter),
            ),
          );
        },
      ),
    );
  }
}

class _PaymentActionButton extends ConsumerWidget {
  final UserModel user;
  final AppLocalizations l;
  const _PaymentActionButton({required this.user, required this.l});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markingPaid = !user.isPaid;
    final color = markingPaid ? AppColors.success : AppColors.errorRed;
    final icon = markingPaid
        ? Icons.check_circle_outline
        : Icons.highlight_off_rounded;
    final label = markingPaid ? l.paid : l.unpaid;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => confirmTogglePayment(
          context,
          ref,
          uid: user.uid,
          name: user.name,
          paidUntil: user.paidUntil,
        ),
        icon: Icon(icon, color: AppColors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
