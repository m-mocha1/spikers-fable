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
import '../../core/utils/title_case.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../l10n/app_localizations.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import 'animations.dart';
import 'attendee_facepile.dart';
import 'date_block.dart';

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

    // Fill ratio drives the left accent stripe and the capacity bar colour
    // (green → orange → red), reusing the same thresholds as the spots
    // indicator below.
    final filled = session.attendeeIds.length;
    final ratio = session.maxPlayers > 0 ? filled / session.maxPlayers : 1.0;
    final statusColor = ratio >= 1.0
        ? AppColors.errorRed
        : ratio >= 0.8
            ? Colors.orange
            : AppColors.success;

    // Ticket-style header: weekday + kick-off time as a gold overline so the
    // eye lands on *when* first, then the title. Bare DateFormat picks up
    // Intl.defaultLocale (set in main.dart), so this localizes for Arabic.
    final overline =
        '${DateFormat('EEEE').format(session.startTime)} • ${DateFormat('HH:mm').format(session.startTime)}'
            .toUpperCase();

    // Content rows, extracted so they can be re-wrapped in an entrance
    // cascade when the user navigates back from the detail screen. On first
    // mount they render plain — the list's AppStaggeredItem already animates
    // the whole card, and double-fading the text would look muddy.
    final contentRows = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateBlock(session.startTime),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        overline,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                          letterSpacing: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (session.isOngoing)
                      Pulse(
                          child:
                              _Badge(l.live.toUpperCase(), AppColors.success)),
                    if (session.isFull && !session.isOngoing)
                      _Badge(l.full.toUpperCase(), AppColors.errorRed),
                    _MembershipBadge(session),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  session.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, height: 1.15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Icon(Icons.location_on_outlined,
              size: 16, color: AppColors.grey),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              session.location.toTitleCase(),
              style: const TextStyle(color: AppColors.grey, fontSize: 14.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          AttendeeFacepile(session.attendeeIds),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          _GenderBadge(session.gender),
          // The waitlist earns a mention only when someone is actually on it —
          // an ever-present "0/6" was a second unlabeled ratio competing with
          // the capacity count.
          if (session.waitlistIds.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(child: _WaitlistPill(session)),
          ],
        ],
      ),
      const SizedBox(height: 10),
      // The card's single ratio: a labeled head-count and the capacity bar it
      // measures, reading as one assembly.
      Row(
        children: [
          Icon(Icons.group_outlined, size: 17, color: statusColor),
          const SizedBox(width: 5),
          Text(
            l.joinedCount(filled, session.maxPlayers),
            style: TextStyle(
              fontSize: 13.5,
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _CapacityBar(ratio: ratio, color: statusColor)),
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
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
          // Layered depth: a soft ambient drop + a tight contact shadow, and a
          // gentle green halo while the session is live.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
            if (session.isOngoing)
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.22),
                blurRadius: 26,
                spreadRadius: 1,
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
                      const DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: AppGradients.cardSheen),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: content,
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim capacity meter along the card's bottom edge — the stripe colour,
/// restated as *how full* the session is. Animates on mount and whenever the
/// attendee count changes.
class _CapacityBar extends StatelessWidget {
  final double ratio;
  final Color color;
  const _CapacityBar({required this.ratio, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
      duration: AppMotion.slow,
      curve: AppMotion.enter,
      builder: (context, value, child) => Container(
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(2),
        ),
        alignment: AlignmentDirectional.centerStart,
        child: value <= 0
            ? const SizedBox.shrink()
            : FractionallySizedBox(
                widthFactor: value,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
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

/// Compact labeled pill for a non-empty waitlist ("Waitlist · 2") — named, so
/// it can't be mistaken for the capacity count. Turns red once the waitlist
/// itself is full.
class _WaitlistPill extends StatelessWidget {
  final SessionModel session;
  const _WaitlistPill(this.session);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final color = session.isWaitlistFull ? AppColors.errorRed : AppColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_bottom, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${l.waitlist} · ${session.waitlistIds.length}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
