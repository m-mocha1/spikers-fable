import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';

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
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.person_outline,
            label: l.gender,
            value: user.gender == 'male' ? l.male : l.female,
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
    final safeAge = user.age < 0 ? 0 : user.age;
    final height = user.heightCm?.toString() ?? '—';
    final weight = user.weightKg?.toString() ?? '—';

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _StatCell(value: height, unit: l.heightHint)),
          const _StatDivider(),
          Expanded(child: _StatCell(value: weight, unit: l.weightHint)),
          const _StatDivider(),
          Expanded(child: _StatCell(value: '$safeAge', unit: l.years)),
        ],
      ),
    );

    if (onEdit == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: card,
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String unit;
  const _StatCell({required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: const TextStyle(
            color: AppColors.grey,
            fontSize: 12,
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
      height: 32,
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
    final safeDays = daysLeft < 0 ? 0 : daysLeft;
    final Color color;
    final String label;
    if (isLifetime) {
      color = AppColors.gold;
      label = l.lifetime;
    } else if (!isPaid || safeDays == 0) {
      color = AppColors.errorRed;
      label = isPaid ? l.daysLeft(0) : l.unpaid;
    } else if (safeDays <= 10) {
      color = AppColors.warning;
      label = '${l.paid} · ${l.daysLeft(safeDays)}';
    } else {
      color = AppColors.success;
      label = '${l.paid} · ${l.daysLeft(safeDays)}';
    }

    return Row(
      children: [
        const Icon(Icons.payments_outlined, size: 18, color: AppColors.gold),
        const SizedBox(width: 10),
        Text(l.payment, style: const TextStyle(color: AppColors.grey)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
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
