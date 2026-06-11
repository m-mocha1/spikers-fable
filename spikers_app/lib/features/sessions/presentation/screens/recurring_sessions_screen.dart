import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart'
    show ExtensionSnackbar, Get, GetNavigation, SnackPosition;

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/recurring_session_model.dart';
import '../../../../routes/app_routes.dart';
import '../providers/sessions_providers.dart';

class RecurringSessionsScreen extends ConsumerWidget {
  const RecurringSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final dayLabels = [l.sun, l.mon, l.tue, l.wed, l.thu, l.fri, l.sat];
    final recurringAsync = ref.watch(recurringSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.recurringSessions)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.toNamed(Routes.createRecurring),
        child: const Icon(Icons.add),
      ),
      body: recurringAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(
          child: Text(l.errorOccurred,
              style: const TextStyle(color: AppColors.grey, fontSize: 15)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.repeat, size: 64, color: AppColors.grey),
                    const SizedBox(height: 16),
                    Text(l.noRecurringSessions,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(l.noRecurringSessionsDesc,
                        style: const TextStyle(
                            color: AppColors.grey, fontSize: 14),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: items.length,
            itemBuilder: (_, i) => _RecurringCard(
              model: items[i],
              dayLabels: dayLabels,
              l: l,
            ),
          );
        },
      ),
    );
  }
}

class _RecurringCard extends ConsumerWidget {
  final RecurringSessionModel model;
  final List<String> dayLabels;
  final AppLocalizations l;
  const _RecurringCard({
    required this.model,
    required this.dayLabels,
    required this.l,
  });

  String _fmtTime(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.confirmDeleteRecurring),
        content: Text(l.confirmDeleteRecurringBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(recurringSessionsRepositoryProvider).delete(model.id);
      Get.snackbar('', l.recurringDeleted,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2));
    } catch (_) {
      Get.snackbar('', l.errorOccurred, snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeStr =
        '${_fmtTime(model.startHour, model.startMinute)} – ${_fmtTime(model.endHour, model.endMinute)}';

    return GestureDetector(
      onTap: () => Get.toNamed(Routes.createRecurring, arguments: model),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: model.enabled
              ? AppColors.navyLight
              : AppColors.navyLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(model.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Switch(
                  value: model.enabled,
                  onChanged: (v) => ref
                      .read(recurringSessionsRepositoryProvider)
                      .toggleEnabled(model.id, v),
                  activeThumbColor: AppColors.gold,
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.grey),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(model.location,
                      style:
                          const TextStyle(color: AppColors.grey, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time,
                    size: 13, color: AppColors.grey),
                const SizedBox(width: 3),
                Text(timeStr,
                    style:
                        const TextStyle(color: AppColors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: List.generate(7, (d) {
                      final active = model.recurrenceDays.contains(d);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.gold.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active
                                ? AppColors.gold
                                : AppColors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          dayLabels[d],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: active ? AppColors.gold : AppColors.grey,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppColors.grey),
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
