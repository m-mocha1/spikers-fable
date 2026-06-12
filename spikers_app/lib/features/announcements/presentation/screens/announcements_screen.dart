import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_snackbar.dart';
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
    final announcementsAsync = ref.watch(announcementsProvider);
    final myUid = ref.watch(currentUserProvider).value?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(l.announcements)),
      floatingActionButton: isCoach
          ? FloatingActionButton(
              onPressed: () async {
                await context.push(Routes.createAnnouncement);
                await markAnnouncementsRead(ref);
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: announcementsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(
          child: Text(l.errorOccurred,
              style: const TextStyle(color: AppColors.grey, fontSize: 15)),
        ),
        data: (announcements) {
          if (announcements.isEmpty) {
            return Center(
              child: Text(l.noAnnouncements,
                  style:
                      const TextStyle(color: AppColors.grey, fontSize: 15)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: announcements.length,
            itemBuilder: (_, i) => _AnnouncementCard(
              announcement: announcements[i],
              isAuthor:
                  myUid != null && announcements[i].authorId == myUid,
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
  const _AnnouncementCard({
    required this.announcement,
    required this.isAuthor,
  });

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
                child: Text(announcement.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              if (isAuthor) ...[
                _CardIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: l.editAnnouncement,
                  onTap: () async {
                    await context.push(Routes.createAnnouncement,
                        extra: announcement);
                    await markAnnouncementsRead(ref);
                  },
                ),
                _CardIconButton(
                  icon: Icons.delete_outline,
                  tooltip: l.delete,
                  onTap: () => _confirmDelete(context, ref),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(announcement.body,
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
                        child: Text(announcement.authorName,
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

class _CardIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _CardIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: AppColors.grey),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
