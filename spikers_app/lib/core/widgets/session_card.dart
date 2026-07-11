import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_gradients.dart';
import '../../core/constants/app_motion.dart';
import '../../core/router/app_router.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../l10n/app_localizations.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import 'package:spikers_app/features/sessions/domain/repositories/sessions_repository.dart'
    show PublicProfile;
import 'package:spikers_app/features/sessions/presentation/providers/sessions_providers.dart';
import 'animations.dart';

class SessionCard extends StatefulWidget {
  final SessionModel session;
  const SessionCard({super.key, required this.session});

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  /// Bumped each time the user returns from the detail screen. Remounts the
  /// card's content column so its rows replay a staggered entrance while the
  /// hero art flies back into the card — the card "reassembles" on return.
  int _returnGeneration = 0;

  Future<void> _openDetail() async {
    await context.push(Routes.sessionDetail, extra: widget.session);
    if (mounted) setState(() => _returnGeneration++);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final l = AppLocalizations.of(context)!;
    final designAsset = AppAssets
        .cardDesigns[session.designIndex % AppAssets.cardDesigns.length];

    // Fill ratio drives the left accent stripe colour (green → orange → red),
    // reusing the same thresholds as the spots indicator below.
    final filled = session.attendeeIds.length;
    final ratio = session.maxPlayers > 0 ? filled / session.maxPlayers : 1.0;
    final statusColor = ratio >= 1.0
        ? AppColors.errorRed
        : ratio >= 0.8
            ? Colors.orange
            : AppColors.success;

    // Content rows, extracted so they can be re-wrapped in an entrance
    // cascade when the user navigates back from the detail screen. On first
    // mount they render plain — the list's AppStaggeredItem already animates
    // the whole card, and double-fading the text would look muddy.
    final contentRows = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              session.title,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          if (session.isOngoing)
            Pulse(child: _Badge(l.live.toUpperCase(), AppColors.success)),
          if (session.isFull && !session.isOngoing)
            _Badge(l.full.toUpperCase(), AppColors.errorRed),
          _MembershipBadge(session),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          const Icon(Icons.location_on_outlined,
              size: 17, color: AppColors.grey),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              session.location,
              style: const TextStyle(color: AppColors.grey, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _Facepile(session.attendeeIds),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          _InfoChip(
            icon: Icons.schedule,
            label: DateFormat('MMM d  HH:mm').format(session.startTime),
          ),
          const SizedBox(width: 12),
          _GenderBadge(session.gender),
          const Spacer(),
          _SpotsIndicator(session),
          if (session.hasWaitlist) ...[
            const SizedBox(width: 10),
            _WaitlistIndicator(session),
          ],
        ],
      ),
    ];

    // Left status stripe — revealed with the content: after the art settles
    // it fades in and "draws" downward (a vertical wipe), the tall-thin
    // equivalent of the rows' fade + upward drift.
    final stripe = Container(width: 5, color: statusColor);
    final animatedStripe = _returnGeneration == 0
        ? stripe
        : stripe
            .animate(
              key: ValueKey(_returnGeneration),
              delay: AppMotion.heroSettle,
            )
            .fadeIn(duration: AppMotion.normal, curve: AppMotion.enter)
            .scale(
              begin: const Offset(1, 0),
              end: const Offset(1, 1),
              alignment: Alignment.topCenter,
              duration: AppMotion.normal,
              curve: AppMotion.enter,
            );

    final content = _returnGeneration == 0
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contentRows,
          )
        : KeyedSubtree(
            key: ValueKey(_returnGeneration),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // Image first: hold until the hero art settles back into the
              // card, then reveal each row with a fade + small upward drift.
              children: contentRows
                  .animate(
                    delay: AppMotion.heroSettle,
                    interval: AppMotion.stagger,
                  )
                  .fadeIn(duration: AppMotion.normal, curve: AppMotion.enter)
                  .moveY(
                    begin: AppMotion.revealShift,
                    end: 0,
                    curve: AppMotion.enter,
                  ),
            ),
          );

    return Pressable(
      onTap: _openDetail,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background artwork + a bottom-up scrim so text stays legible over
            // any of the card designs. Wrapped in a Hero so tapping the card
            // morphs this art into the banner on the session detail screen;
            // the Hero carries its own rounded clip because the flight renders
            // outside the card's clipBehavior.
            Positioned.fill(
              child: Hero(
                tag: 'session_art_${session.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(designAsset, fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: AppGradients.cardScrim),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Left status stripe.
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              child: animatedStripe,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: content,
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _Badge(this.label, this.color, {this.textColor = AppColors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
    );
  }
}

/// The viewer's own relationship to the session, visible without opening it:
/// a green "JOINED" badge, or their gold "#N" waitlist position. Renders
/// nothing for sessions they're not part of.
class _MembershipBadge extends ConsumerWidget {
  final SessionModel session;
  const _MembershipBadge(this.session);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider).value?.uid ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    if (session.isJoinedBy(uid)) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 6),
        child: _Badge(l.joinedBadge.toUpperCase(), AppColors.success),
      );
    }
    final idx = session.waitlistIds.indexOf(uid);
    if (idx >= 0) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 6),
        child: _Badge(
          '#${idx + 1}',
          AppColors.gold,
          textColor: AppColors.navyBlue,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.gold),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.grey)),
      ],
    );
  }
}

class _GenderBadge extends StatelessWidget {
  final String gender;
  const _GenderBadge(this.gender);

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (gender) {
      case 'male':
        color = AppColors.gold;
        icon = Icons.male;
        break;
      case 'female':
        color = Colors.pinkAccent;
        icon = Icons.female;
        break;
      default:
        color = AppColors.gold;
        icon = Icons.people_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            gender == 'male'
                ? AppLocalizations.of(context)!.male
                : gender == 'female'
                    ? AppLocalizations.of(context)!.female
                    : AppLocalizations.of(context)!.genderMixed,
            style: TextStyle(
                fontSize: 13, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SpotsIndicator extends StatelessWidget {
  final SessionModel session;
  const _SpotsIndicator(this.session);

  @override
  Widget build(BuildContext context) {
    final filled = session.attendeeIds.length;
    final max = session.maxPlayers;
    final ratio = max > 0 ? filled / max : 1.0;
    final color =
        ratio >= 1.0 ? AppColors.errorRed : ratio >= 0.8 ? Colors.orange : AppColors.success;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.group_outlined, size: 17, color: color),
        const SizedBox(width: 5),
        Text('$filled/$max',
            style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Overlapping attendee avatars ("+N" when there are more) — makes a card read
/// as *people playing*, not just a capacity number. Renders nothing while the
/// profile fetch is in flight or when the session is empty.
class _Facepile extends ConsumerWidget {
  final List<String> uids;
  const _Facepile(this.uids);

  static const _maxFaces = 3;
  static const double _diameter = 24;
  static const double _step = 15;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (uids.isEmpty) return const SizedBox.shrink();
    final shown = uids.take(_maxFaces).join(',');
    final profiles = ref.watch(facepileProfilesProvider(shown)).value;
    if (profiles == null || profiles.isEmpty) return const SizedBox.shrink();
    final extra = uids.length - profiles.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _diameter + _step * (profiles.length - 1),
          height: _diameter,
          child: Stack(
            children: [
              for (var i = 0; i < profiles.length; i++)
                PositionedDirectional(
                  start: i * _step,
                  child: _FaceDot(profiles[i]),
                ),
            ],
          ),
        ),
        if (extra > 0) ...[
          const SizedBox(width: 4),
          Text(
            '+$extra',
            style: const TextStyle(
              color: AppColors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _FaceDot extends StatelessWidget {
  final PublicProfile profile;
  const _FaceDot(this.profile);

  @override
  Widget build(BuildContext context) {
    final initial =
        profile.name.trim().isEmpty ? '?' : profile.name.trim()[0].toUpperCase();
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Ring in the card surface colour so stacked faces separate cleanly.
        border: Border.all(color: AppColors.navyLight, width: 2),
      ),
      child: CircleAvatar(
        radius: 10,
        backgroundColor: AppColors.gold.withValues(alpha: 0.25),
        backgroundImage: profile.photoUrl.isNotEmpty
            ? CachedNetworkImageProvider(profile.photoUrl)
            : null,
        child: profile.photoUrl.isEmpty
            ? Text(
                initial,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }
}

class _WaitlistIndicator extends StatelessWidget {
  final SessionModel session;
  const _WaitlistIndicator(this.session);

  @override
  Widget build(BuildContext context) {
    final filled = session.waitlistIds.length;
    final size = session.waitlistSize;
    final color =
        session.isWaitlistFull ? AppColors.errorRed : AppColors.gold;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.hourglass_bottom, size: 16, color: color),
        const SizedBox(width: 4),
        Text('$filled/$size',
            style: TextStyle(
                fontSize: 14, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
