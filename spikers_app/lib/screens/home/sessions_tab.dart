import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../controller/auth_controller.dart';
import '../../controller/session_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/session_card.dart';
import 'home_screen.dart';

class SessionsTab extends StatelessWidget {
  const SessionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SessionController>();
    final auth = Get.find<AuthController>();
    return Obx(() {
      if (ctrl.isLoading.value) return _buildShimmer(context);
      if (ctrl.hasError.value) return _buildError(context, ctrl);
      if (ctrl.sessions.isEmpty) {
        final user = auth.currentUser.value;
        if (user != null && !user.isCoach && !user.isPaid) {
          return _buildPaywall(context);
        }
        return buildEmptyState(context);
      }
      return RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => ctrl.fetchSessions(),
        child: ListView.builder(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 100),
          itemCount: ctrl.sessions.length,
          itemBuilder: (_, i) => SessionCard(session: ctrl.sessions[i]),
        ),
      );
    });
  }

  Widget _buildPaywall(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline,
                size: 64, color: AppColors.grey),
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

  Widget _buildError(BuildContext context, SessionController ctrl) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 64, color: AppColors.grey),
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
              onPressed: ctrl.fetchSessions,
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
