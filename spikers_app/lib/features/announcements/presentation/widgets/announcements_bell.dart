import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/announcements_providers.dart';

/// App-bar bell with the unread dot. Riverpod widget embedded in the (still
/// GetX) home screen — ProviderScope sits at the app root, so this works
/// anywhere in the tree.
class AnnouncementsBell extends ConsumerWidget {
  const AnnouncementsBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final hasUnread = ref.watch(hasUnreadAnnouncementsProvider);
    return IconButton(
      tooltip: l.announcements,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (hasUnread)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.errorRed,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      onPressed: () => context.push(Routes.announcements),
    );
  }
}
