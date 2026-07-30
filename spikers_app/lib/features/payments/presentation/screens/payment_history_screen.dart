import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/payment_record.dart';
import '../providers/payments_providers.dart';

/// Read-only view of a user's payment audit log
/// (users/{uid}/payments). Reachable from a coach/admin's player profile
/// (any player's log) and from a user's own profile tab (their own log);
/// the Firestore rules enforce who may read which.
class PaymentHistoryScreen extends ConsumerWidget {
  final String userId;
  const PaymentHistoryScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final historyAsync = ref.watch(paymentHistoryProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(l.paymentHistory)),
      body: historyAsync.when(
        loading: () => const ListShimmer(itemHeight: 76),
        error: (e, _) => ErrorView(
            onRetry: () => ref.invalidate(paymentHistoryProvider(userId))),
        data: (records) {
          if (records.isEmpty) {
            return EmptyStateView(
                icon: Icons.receipt_long_outlined,
                title: l.noPaymentHistory);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            itemCount: records.length,
            itemBuilder: (_, i) => AppStaggeredItem(
              index: i,
              child: _PaymentRecordCard(record: records[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PaymentRecordCard extends StatelessWidget {
  final PaymentRecord record;
  const _PaymentRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final fmt = DateFormat('MMM d, yyyy · HH:mm');
    // The expiry an adjustment leaves behind is a date, not a moment.
    final dayFmt = DateFormat('MMM d, yyyy');
    // Three states: days added (green), days taken back off a membership that
    // stayed active (amber), and deactivation (red).
    final semantic = context.semanticColors;
    final Color color;
    final IconData icon;
    final String label;
    if (record.isReduction) {
      color = semantic.warning;
      icon = Icons.remove_circle_outline;
      label = l.daysRemoved;
    } else if (record.isPaid) {
      color = semantic.success;
      icon = Icons.check_circle_outline;
      label = l.paid;
    } else {
      color = semantic.danger;
      icon = Icons.highlight_off_rounded;
      label = l.unpaid;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w700)),
                // Only adjustments made since coaches could choose the length
                // carry a day count; older records skip straight to the date.
                if (record.days != null && record.until != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.days! < 0
                        ? l.removedForDays(
                            -record.days!, dayFmt.format(record.until!))
                        : l.renewedForDays(
                            record.days!, dayFmt.format(record.until!)),
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 4),
                Text(fmt.format(record.changedAt),
                    style: const TextStyle(
                        color: AppColors.grey, fontSize: 12)),
                if (record.changedByName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(l.paymentChangedBy(record.changedByName),
                      style: const TextStyle(
                          color: AppColors.grey, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
