import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Shimmer skeleton row for the session list.
class SessionShimmer extends StatelessWidget {
  const SessionShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

Widget buildEmptyState(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.sports_volleyball_outlined,
            size: 64, color: AppColors.grey),
        const SizedBox(height: 16),
        Text(l.noSessions,
            style: const TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(l.noSessionsDesc,
            style: const TextStyle(color: AppColors.grey, fontSize: 14),
            textAlign: TextAlign.center),
      ],
    ),
  );
}
