import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/announcement_controller.dart';
import '../../controller/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/announcement_model.dart';
import '../../routes/app_routes.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<AnnouncementController>().markRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final auth = Get.find<AuthController>();

    return Scaffold(
      appBar: AppBar(title: Text(l.announcements)),
      floatingActionButton: Obx(() => auth.isCoach
          ? FloatingActionButton(
              onPressed: () async {
                await Get.toNamed(Routes.createAnnouncement);
                await Get.find<AnnouncementController>().markRead();
              },
              child: const Icon(Icons.add),
            )
          : const SizedBox.shrink()),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return Center(
              child: Text(l.errorOccurred,
                  style: const TextStyle(
                      color: AppColors.grey, fontSize: 15)),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(l.noAnnouncements,
                  style: const TextStyle(
                      color: AppColors.grey, fontSize: 15)),
            );
          }
          return Obx(() {
            final myUid = auth.currentUser.value?.uid;
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final announcement = AnnouncementModel.fromDoc(docs[i]);
                return _AnnouncementCard(
                  announcement: announcement,
                  isAuthor:
                      myUid != null && announcement.authorId == myUid,
                );
              },
            );
          });
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  final bool isAuthor;
  const _AnnouncementCard({
    required this.announcement,
    required this.isAuthor,
  });

  String _relativeTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDelete(BuildContext context) async {
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
      await Get.find<AnnouncementController>().delete(announcement.id);
      Get.snackbar('', l.announcementDeleted,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2));
    } catch (_) {
      Get.snackbar('', l.errorOccurred,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    await Get.toNamed(Routes.createAnnouncement,
                        arguments: announcement);
                    await Get.find<AnnouncementController>().markRead();
                  },
                ),
                _CardIconButton(
                  icon: Icons.delete_outline,
                  tooltip: l.delete,
                  onTap: () => _confirmDelete(context),
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
              Text('· ${_relativeTime(announcement.createdAt)}',
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
