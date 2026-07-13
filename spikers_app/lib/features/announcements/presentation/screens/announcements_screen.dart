import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/bidi.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/floating_nav_bar.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/announcement.dart';
import '../providers/announcements_providers.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      markAnnouncementsRead(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isCoach = ref.watch(isCoachProvider);
    final announcementsAsync = ref.watch(visibleAnnouncementsProvider);
    final myUid = ref.watch(currentUserProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(l.announcements)),
      floatingActionButton: isCoach
          ? FloatingActionButton(
              tooltip: l.newAnnouncement,
              onPressed: () async {
                await context.push(Routes.createAnnouncement);
                await markAnnouncementsRead(ref);
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: announcementsAsync.when(
        loading: () => const ListShimmer(itemHeight: 110),
        error: (e, _) => ErrorView(
            onRetry: () => ref.invalidate(announcementsProvider)),
        data: (announcements) {
          if (announcements.isEmpty) {
            return EmptyStateView(
              icon: Icons.campaign_outlined,
              title: l.noAnnouncements,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                16, 16, 16, FloatingNavBar.scrollClearance),
            itemCount: announcements.length,
            itemBuilder: (_, i) => AppStaggeredItem(
              index: i,
              child: _AnnouncementCard(
                announcement: announcements[i],
                isAuthor:
                    myUid != null && announcements[i].authorId == myUid,
                canDelete: isCoach ||
                    (myUid != null && announcements[i].authorId == myUid),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  final AnnouncementModel announcement;
  final bool isAuthor;
  final bool canDelete;
  const _AnnouncementCard({
    required this.announcement,
    required this.isAuthor,
    required this.canDelete,
  });

  /// Human label for a non-'all' audience. Phrased as "For men"/"For women"
  /// so the reader doesn't mistake it for a label of the author.
  String _audienceLabel(AppLocalizations l) {
    switch (announcement.audience) {
      case 'male':
        return l.audienceMen;
      case 'female':
        return l.audienceWomen;
      default:
        return l.allGenders;
    }
  }

  String _relativeTime(AppLocalizations l, DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return l.justNow;
    if (diff.inHours < 1) return l.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l.daysAgo(diff.inDays);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.confirmDeleteAnnouncement),
        content: Text(l.confirmDeleteAnnouncementBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(announcementsRepositoryProvider)
          .delete(announcement.id);
      showAppSnackbar(l.announcementDeleted,
          duration: const Duration(seconds: 2));
    } catch (_) {
      showAppSnackbar(l.errorOccurred);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                // Bidi isolation: mixed AR/EN titles keep their own reading
                // order instead of shredding around the surrounding layout.
                child: Text(bidiIsolate(announcement.title),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              // Destructive action quarantined behind an overflow menu
              // instead of an always-exposed trash icon next to the title
              // (Premium Pass Phase 7).
              if (isAuthor || canDelete)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 20, color: AppColors.grey),
                  color: AppColors.navyLight,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 160),
                  onSelected: (action) async {
                    switch (action) {
                      case 'edit':
                        await context.push(Routes.createAnnouncement,
                            extra: announcement);
                        await markAnnouncementsRead(ref);
                      case 'delete':
                        await _confirmDelete(context, ref);
                    }
                  },
                  itemBuilder: (_) => [
                    if (isAuthor)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined,
                                size: 18, color: AppColors.gold),
                            const SizedBox(width: 10),
                            Text(l.editAnnouncement),
                          ],
                        ),
                      ),
                    if (canDelete)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline,
                                size: 18, color: AppColors.errorRed),
                            const SizedBox(width: 10),
                            Text(l.delete,
                                style: const TextStyle(
                                    color: AppColors.errorRed)),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(bidiIsolate(announcement.body),
              style: const TextStyle(fontSize: 14, height: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sports,
                          size: 14, color: AppColors.gold),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(bidiIsolate(announcement.authorName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              if (announcement.audience != 'all') ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.grey.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group_outlined,
                          size: 14, color: AppColors.grey),
                      const SizedBox(width: 6),
                      Text(_audienceLabel(l),
                          style: const TextStyle(
                              color: AppColors.grey,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Text('· ${_relativeTime(l, announcement.createdAt)}',
                  style: const TextStyle(
                      color: AppColors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

