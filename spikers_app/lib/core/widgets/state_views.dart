import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'animations.dart';

/// Shared async-state widgets (per CLAUDE.md: LoadingView / ErrorView /
/// EmptyStateView). Every list/detail screen renders these instead of
/// hand-rolled spinners and centered strings, so the three states look and
/// behave the same everywhere.

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.gold),
    );
  }
}

class ErrorView extends StatelessWidget {
  /// Defaults to the localized generic error message.
  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorView({
    super.key,
    this.message,
    this.onRetry,
    this.icon = Icons.wifi_off_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: AppFadeIn(
        child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Floating(child: Icon(icon, size: 64, color: AppColors.grey)),
            const SizedBox(height: 16),
            Text(
              message ?? l.errorOccurred,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l.retry),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 48),
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  /// Optional call-to-action rendered below the subtitle (e.g. a button that
  /// opens a dialog to resolve the empty state).
  final Widget? action;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppFadeIn(
        child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Floating(child: Icon(icon, size: 64, color: AppColors.grey)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey, fontSize: 14),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
        ),
      ),
    );
  }
}

/// Shimmer stand-in for one person row (avatar circle + name/subtitle bars)
/// while that uid's public profile is still loading. Sized to match the real
/// attendee/waitlist rows so the swap to live data causes no layout shift.
/// Colours are inverted relative to [ListShimmer] because these rows sit
/// inside a navyLight card rather than on the gradient background.
class PersonRowShimmer extends StatelessWidget {
  /// Effective avatar radius including any ring the real row draws (the
  /// attendee avatar is radius 19 plus a 2px border, hence 21).
  final double avatarRadius;

  /// Attendee rows carry a subtitle line ("N sessions attended");
  /// waitlist rows don't.
  final bool showSubtitle;

  const PersonRowShimmer({
    super.key,
    this.avatarRadius = 21,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.navyBlue,
            borderRadius: BorderRadius.circular(4),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Shimmer.fromColors(
        baseColor: AppColors.navyBlue,
        highlightColor: AppColors.grey.withValues(alpha: 0.35),
        child: Row(
          children: [
            Container(
              width: avatarRadius * 2,
              height: avatarRadius * 2,
              decoration: const BoxDecoration(
                color: AppColors.navyBlue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(140, 12),
                if (showSubtitle) ...[
                  const SizedBox(height: 6),
                  bar(90, 9),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder for card lists while the first snapshot loads —
/// matches the rounded-card look of the real rows it stands in for.
class ListShimmer extends StatelessWidget {
  final double itemHeight;
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const ListShimmer({
    super.key,
    this.itemHeight = 72,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.navyLight,
      highlightColor: AppColors.navyBlue,
      child: ListView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, _) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: itemHeight,
          decoration: BoxDecoration(
            color: AppColors.navyLight,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
