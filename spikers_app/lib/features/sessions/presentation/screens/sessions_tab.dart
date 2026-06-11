import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/core/widgets/session_card.dart';
import '../widgets/session_list_states.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/sessions_providers.dart';

class SessionsTab extends ConsumerWidget {
  const SessionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(upcomingSessionsProvider);

    return sessionsAsync.when(
      loading: () => _buildShimmer(context),
      error: (e, _) => _buildError(context, ref),
      data: (sessions) {
        if (sessions.isEmpty) {
          final user = ref.watch(currentUserProvider).value;
          if (user != null && !user.isCoach && !user.isPaid) {
            return _buildPaywall(context);
          }
          return buildEmptyState(context);
        }
        return RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () async {
            ref.invalidate(upcomingSessionsProvider);
            await ref.read(upcomingSessionsProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 100),
            itemCount: sessions.length,
            itemBuilder: (_, i) => SessionCard(session: sessions[i]),
          ),
        );
      },
    );
  }

  Widget _buildPaywall(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: AppColors.grey),
            const SizedBox(height: 16),
            Text(
              l.paymentRequired,
              style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l.paymentRequiredDesc,
              style: const TextStyle(color: AppColors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_outlined,
                size: 64, color: AppColors.grey),
            const SizedBox(height: 16),
            Text(
              l.errorOccurred,
              style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(upcomingSessionsProvider),
              icon: const Icon(Icons.refresh),
              label: Text(l.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.navyLight,
      highlightColor: AppColors.navyBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => const SessionShimmer(),
      ),
    );
  }
}
