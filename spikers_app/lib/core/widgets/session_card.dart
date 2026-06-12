import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../l10n/app_localizations.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';

class SessionCard extends StatelessWidget {
  final SessionModel session;
  const SessionCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final designAsset = AppAssets
        .cardDesigns[session.designIndex % AppAssets.cardDesigns.length];

    return GestureDetector(
      onTap: () => context.push(Routes.sessionDetail, extra: session),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(
            image: AssetImage(designAsset),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (session.isOngoing)
                    _Badge(l.live.toUpperCase(), AppColors.success),
                  if (session.isFull && !session.isOngoing)
                    _Badge(l.full.toUpperCase(), AppColors.errorRed),
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
            ],
          ),
        ),
      ),
    );
  }

}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.white)),
    );
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
