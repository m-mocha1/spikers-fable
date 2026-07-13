import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_gradients.dart';
import '../../../../core/constants/app_image_fx.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/attendee_facepile.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../domain/entities/session_model.dart';

/// The greeting + personal spotlight that sits above the session list, turning
/// the sessions tab from a bare list into a screen with a focal point.
///
/// Pure presentation: everything is derived from data the tab already watches
/// (the signed-in [user] and the upcoming [sessions] list) — no extra reads.
class SessionsHeader extends StatelessWidget {
  final UserModel user;
  final List<SessionModel> sessions;
  const SessionsHeader({
    super.key,
    required this.user,
    required this.sessions,
  });

  /// The viewer's own next commitment (attendee or waitlist), earliest first —
  /// the session the Next-Up hero spotlights. Exposed so the list below can
  /// compress that session's entry instead of rendering it twice on one screen.
  static SessionModel? nextUpFor(UserModel user, List<SessionModel> sessions) {
    final now = DateTime.now();
    final mine = sessions
        .where((s) =>
            (s.isJoinedBy(user.uid) || s.isWaitlistedBy(user.uid)) &&
            s.endTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return mine.isEmpty ? null : mine.first;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final now = DateTime.now();

    final firstName = user.name.trim().isEmpty
        ? ''
        : user.name.trim().split(' ').first;

    final next = nextUpFor(user, sessions);

    final weekCount = sessions
        .where((s) =>
            s.startTime.isAfter(now) &&
            s.startTime.isBefore(now.add(const Duration(days: 7))))
        .length;

    return AppFadeIn(
      slide: 0.05,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Editorial date overline — anchors the screen in "today" the way
            // Apple Fitness does, and gives the greeting a gold counterpoint.
            Text(
              DateFormat.MMMMEEEEd().format(now).toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.gold,
                letterSpacing: 1.6,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              _greeting(l, firstName),
              // Styled locally (not via textTheme.display*) so the hero scale
              // never leaks into Material widgets like the time picker.
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            if (next != null) ...[
              _NextUpHero(
                session: next,
                l: l,
                isWaitlisted: next.isWaitlistedBy(user.uid),
              ),
              const SizedBox(height: 26),
            ] else if (!user.isCoach) ...[
              // Players with nothing booked get a nudge; coaches get nothing
              // here — the UPCOMING count pill below already summarizes the
              // schedule, so a "N upcoming sessions" card would say it twice.
              _NudgeCard(l: l, weekCount: weekCount),
              const SizedBox(height: 26),
            ],
            _SectionLabel(label: l.upcoming, count: sessions.length),
          ],
        ),
      ),
    );
  }

  String _greeting(AppLocalizations l, String name) {
    if (name.isEmpty) return l.welcomeBack;
    final h = DateTime.now().hour;
    if (h < 12) return l.greetingMorning(name);
    if (h < 17) return l.greetingAfternoon(name);
    return l.greetingEvening(name);
  }
}

/// The screen's focal point: the viewer's next booked/waitlisted session as a
/// full event poster — its artwork behind a glowing gold frame, with a live
/// countdown and the people already in. An ambient gloss sweep keeps it alive
/// without demanding attention.
class _NextUpHero extends StatelessWidget {
  final SessionModel session;
  final AppLocalizations l;
  final bool isWaitlisted;
  const _NextUpHero({
    required this.session,
    required this.l,
    required this.isWaitlisted,
  });

  @override
  Widget build(BuildContext context) {
    final designAsset = AppAssets
        .cardDesigns[session.designIndex % AppAssets.cardDesigns.length];
    final when = DateFormat('EEEE • HH:mm').format(session.startTime);

    return Pressable(
      onTap: () => context.push(Routes.sessionDetail, extra: session),
      child: Container(
        width: double.infinity,
        // 2px of gradient shows through as a glowing frame around the art.
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: AppGradients.goldCta,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // The spotlighted session appears in the list below only as a
              // slim art-less stub, so this tag is unique on screen and the
              // art can fly to the detail banner. The Hero carries its own
              // rounded clip because the flight renders outside this ClipRRect.
              Positioned.fill(
                child: Hero(
                  tag: 'session_art_${session.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColorFiltered(
                          colorFilter: AppImageFx.cardArtPop,
                          child: Image.asset(designAsset, fit: BoxFit.cover),
                        ),
                        const DecoratedBox(
                          decoration:
                              BoxDecoration(gradient: AppGradients.heroScrim),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isWaitlisted
                                    ? Icons.hourglass_bottom
                                    : Icons.bolt,
                                size: 15,
                                color: AppColors.gold,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l.nextUp.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            session.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.schedule,
                                  size: 14,
                                  color:
                                      AppColors.white.withValues(alpha: 0.75)),
                              const SizedBox(width: 5),
                              Text(
                                when,
                                style: TextStyle(
                                  color:
                                      AppColors.white.withValues(alpha: 0.75),
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _CountdownChip(startTime: session.startTime),
                              const Spacer(),
                              AttendeeFacepile(
                                session.attendeeIds,
                                ringColor: AppColors.navyBlue,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_left
                          : Icons.chevron_right,
                      color: AppColors.gold,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(
            delay: const Duration(milliseconds: 3200),
            duration: const Duration(milliseconds: 1400),
            angle: 0.6,
            color: AppColors.white.withValues(alpha: 0.10),
          ),
    );
  }
}

/// Frosted-glass countdown to kick-off. Re-renders every 30s so the number is
/// never stale, and flips itself to a pulsing LIVE pill once the session has
/// started — no parent rebuild needed.
class _CountdownChip extends StatefulWidget {
  final DateTime startTime;
  const _CountdownChip({required this.startTime});

  @override
  State<_CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<_CountdownChip> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _format(AppLocalizations l, Duration d) {
    if (d.inDays >= 1) return l.countdownDays(d.inDays);
    if (d.inHours >= 1) return l.countdownHoursMinutes(d.inHours, d.inMinutes % 60);
    return l.countdownMinutes(d.inMinutes < 1 ? 1 : d.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final remaining = widget.startTime.difference(DateTime.now());

    if (remaining.isNegative) {
      return Pulse(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                l.live.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined,
                  size: 13, color: AppColors.gold),
              const SizedBox(width: 5),
              Text(
                '${l.startsIn} ${_format(l, remaining)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when a player has nothing booked: a nudge toward this week's
/// sessions (coaches skip this card entirely — see [SessionsHeader.build]).
class _NudgeCard extends StatelessWidget {
  final AppLocalizations l;
  final int weekCount;
  const _NudgeCard({required this.l, required this.weekCount});

  @override
  Widget build(BuildContext context) {
    final String text;
    final IconData icon;
    if (weekCount > 0) {
      text = l.sessionsThisWeek(weekCount);
      icon = Icons.local_fire_department_outlined;
    } else {
      text = l.findYourNextGame;
      icon = Icons.sports_volleyball_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiet section divider between the spotlight and the list: small-caps label,
/// a count pill, and a hairline that lets the whitespace breathe.
class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  const _SectionLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.white.withValues(alpha: 0.55),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.white.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}
