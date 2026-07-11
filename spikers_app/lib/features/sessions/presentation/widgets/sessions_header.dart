import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_gradients.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/animations.dart';
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final now = DateTime.now();

    final firstName = user.name.trim().isEmpty
        ? ''
        : user.name.trim().split(' ').first;

    // The viewer's own next commitment (attendee or waitlist), earliest first.
    final mine = sessions
        .where((s) =>
            (s.isJoinedBy(user.uid) || s.isWaitlistedBy(user.uid)) &&
            s.endTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final next = mine.isEmpty ? null : mine.first;

    final weekCount = sessions
        .where((s) =>
            s.startTime.isAfter(now) &&
            s.startTime.isBefore(now.add(const Duration(days: 7))))
        .length;

    return AppFadeIn(
      slide: 0.05,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 14),
            if (next != null)
              _NextUpCard(
                session: next,
                l: l,
                isWaitlisted: next.isWaitlistedBy(user.uid),
              )
            else
              _NudgeCard(
                l: l,
                isCoach: user.isCoach,
                weekCount: weekCount,
                totalUpcoming: sessions.length,
              ),
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

/// Gold-bordered spotlight for the viewer's next booked/waitlisted session.
class _NextUpCard extends StatelessWidget {
  final SessionModel session;
  final AppLocalizations l;
  final bool isWaitlisted;
  const _NextUpCard({
    required this.session,
    required this.l,
    required this.isWaitlisted,
  });

  @override
  Widget build(BuildContext context) {
    final when = DateFormat('EEEE • HH:mm').format(session.startTime);
    return Pressable(
      onTap: () => context.push(Routes.sessionDetail, extra: session),
      child: Container(
        width: double.infinity,
        // 2px of gradient shows through as a glowing border around the inner
        // fill.
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: AppGradients.goldCta,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.navyElevated,
            borderRadius: BorderRadius.circular(18),
          ),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 14, color: AppColors.grey),
                        const SizedBox(width: 5),
                        Text(
                          when,
                          style: const TextStyle(
                              color: AppColors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
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

/// Shown when the viewer has nothing booked: a coach sees an upcoming-count
/// summary; a player gets a nudge toward this week's sessions.
class _NudgeCard extends StatelessWidget {
  final AppLocalizations l;
  final bool isCoach;
  final int weekCount;
  final int totalUpcoming;
  const _NudgeCard({
    required this.l,
    required this.isCoach,
    required this.weekCount,
    required this.totalUpcoming,
  });

  @override
  Widget build(BuildContext context) {
    final String text;
    final IconData icon;
    if (isCoach) {
      text = l.upcomingSessionsCount(totalUpcoming);
      icon = Icons.event_available_outlined;
    } else if (weekCount > 0) {
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
          Icon(icon, size: 20, color: AppColors.gold),
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
