import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_motion.dart';
import '../../l10n/app_localizations.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import 'package:spikers_app/features/home/presentation/widgets/profile_stat_cards.dart'
    show profileCardChrome;
import 'membership_chip.dart';

class ProfileRoleBadge extends StatelessWidget {
  final bool isCoach;
  final AppLocalizations l;
  const ProfileRoleBadge({super.key, required this.isCoach, required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isCoach
            ? AppColors.gold.withValues(alpha: 0.15)
            : AppColors.navyLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCoach ? AppColors.gold : AppColors.grey,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCoach ? Icons.sports : Icons.person,
            size: 16,
            color: isCoach ? AppColors.gold : AppColors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            isCoach ? l.coach : l.player,
            style: TextStyle(
              color: isCoach ? AppColors.gold : AppColors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileInfoCard extends StatelessWidget {
  final UserModel user;
  final AppLocalizations l;
  const ProfileInfoCard({super.key, required this.user, required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: profileCardChrome(),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.person_outline,
            label: l.gender,
            value: user.gender == null
                ? l.notSet
                : (user.gender == 'male' ? l.male : l.female),
          ),
          if (!user.isCoach) ...[
            const Divider(height: 20),
            _PaymentRow(
              isPaid: user.isPaid,
              daysLeft: user.paymentDaysLeft,
              isLifetime: user.lifetimeMember,
              l: l,
            ),
          ],
        ],
      ),
    );
  }
}

/// Body-metric stat strip: height / weight / age as icon-topped cells sharing
/// the profile card chrome. When [onEdit] is given the whole card is tappable
/// and carries a quiet pencil affordance in its corner.
class ProfileStatsRow extends StatelessWidget {
  final UserModel user;
  final AppLocalizations l;
  final VoidCallback? onEdit;
  const ProfileStatsRow({
    super.key,
    required this.user,
    required this.l,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final age = user.age;
    final ageText = (age == null || age < 0) ? '—' : '$age';
    final height = user.heightCm?.toString() ?? '—';
    final weight = user.weightKg?.toString() ?? '—';

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: profileCardChrome(),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  icon: Icons.height,
                  value: height,
                  unit: l.heightHint,
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _StatCell(
                  icon: Icons.monitor_weight_outlined,
                  value: weight,
                  unit: l.weightHint,
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _StatCell(
                  icon: Icons.cake_outlined,
                  value: ageText,
                  unit: l.years,
                ),
              ),
            ],
          ),
          if (onEdit != null)
            PositionedDirectional(
              top: 0,
              end: 8,
              child: Icon(
                Icons.edit_outlined,
                size: 14,
                color: AppColors.white.withValues(alpha: 0.35),
              ),
            ),
        ],
      ),
    );

    if (onEdit == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: card,
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  const _StatCell({required this.icon, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    // Count numeric stats up from zero for a bit of life; leave placeholders
    // like "—" static.
    final numeric = int.tryParse(value);
    const style = TextStyle(
      color: AppColors.white,
      fontSize: 24,
      fontWeight: FontWeight.w800,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.gold.withValues(alpha: 0.8)),
        const SizedBox(height: 6),
        numeric == null
            ? Text(value, style: style)
            : TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: numeric),
                duration: AppMotion.slow,
                curve: AppMotion.enter,
                builder: (_, v, _) => Text('$v', style: style),
              ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: const TextStyle(
            color: AppColors.grey,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      color: AppColors.grey.withValues(alpha: 0.25),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final bool isPaid;
  final int daysLeft;
  final bool isLifetime;
  final AppLocalizations l;
  const _PaymentRow(
      {required this.isPaid,
      required this.daysLeft,
      required this.isLifetime,
      required this.l});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.payments_outlined, size: 18, color: AppColors.gold),
        const SizedBox(width: 10),
        Text(l.payment, style: const TextStyle(color: AppColors.grey)),
        const Spacer(),
        // The one membership chip (Phase 6) — same pill everywhere a
        // membership status is shown.
        MembershipChip(
          isPaid: isPaid,
          daysLeft: daysLeft < 0 ? 0 : daysLeft,
          isLifetime: isLifetime,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.gold),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: AppColors.grey)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
