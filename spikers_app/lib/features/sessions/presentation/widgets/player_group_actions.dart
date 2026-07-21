import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/widgets/branded_button.dart';
import '../../../../core/widgets/branded_text_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/player_group_model.dart';
import '../providers/sessions_providers.dart';

/// Shared operations for the coach's saved player groups, used by both the
/// create-session screen and the member picker so save/rename/delete/update
/// behave identically wherever a group is managed.

/// Saves the current [memberIds] as a brand-new named group.
Future<void> saveNewGroup(
  BuildContext context,
  WidgetRef ref, {
  required Set<String> memberIds,
}) async {
  final l = AppLocalizations.of(context)!;
  if (memberIds.isEmpty) {
    showAppSnackbar(l.selectMembersError);
    return;
  }
  final name = await _showGroupNameDialog(context, title: l.saveAsGroup);
  if (name == null || !context.mounted) return;

  final coachUid = ref.read(currentUserProvider).value?.uid;
  if (coachUid == null) return;
  final now = DateTime.now();
  try {
    await ref.read(playerGroupsRepositoryProvider).save(
          PlayerGroup(
            id: '',
            name: name,
            memberIds: memberIds.toList(),
            createdBy: coachUid,
            createdAt: now,
            updatedAt: now,
          ),
        );
    showAppSnackbar(l.groupSaved(name));
  } catch (_) {
    showAppSnackbar(l.unknownError);
  }
}

/// Renames an existing group, keeping its members unchanged.
Future<void> _renameGroup(
    BuildContext context, WidgetRef ref, PlayerGroup group) async {
  final l = AppLocalizations.of(context)!;
  final name = await _showGroupNameDialog(
    context,
    title: l.renameGroup,
    initialName: group.name,
  );
  if (name == null || name == group.name || !context.mounted) return;

  try {
    await ref.read(playerGroupsRepositoryProvider).save(
          PlayerGroup(
            id: group.id,
            name: name,
            memberIds: group.memberIds,
            createdBy: group.createdBy,
            createdAt: group.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
    showAppSnackbar(l.groupUpdated);
  } catch (_) {
    showAppSnackbar(l.unknownError);
  }
}

/// Overwrites a group's members with [memberIds]. Reused by the picker's
/// "Update to current selection" and the create screen's "Edit members" flow.
Future<void> saveGroupMembers(
  BuildContext context,
  WidgetRef ref,
  PlayerGroup group,
  Set<String> memberIds,
) async {
  final l = AppLocalizations.of(context)!;
  if (memberIds.isEmpty) {
    showAppSnackbar(l.selectMembersError);
    return;
  }
  try {
    await ref.read(playerGroupsRepositoryProvider).save(
          PlayerGroup(
            id: group.id,
            name: group.name,
            memberIds: memberIds.toList(),
            createdBy: group.createdBy,
            createdAt: group.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
    showAppSnackbar(l.groupUpdated);
  } catch (_) {
    showAppSnackbar(l.unknownError);
  }
}

/// Confirms, then deletes the group. Players are never touched.
Future<void> _deleteGroup(
    BuildContext context, WidgetRef ref, PlayerGroup group) async {
  final l = AppLocalizations.of(context)!;
  final confirmed = await _showDeleteGroupDialog(context, group.name);
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(playerGroupsRepositoryProvider).delete(group.id);
    showAppSnackbar(l.groupDeleted);
  } catch (_) {
    showAppSnackbar(l.unknownError);
  }
}

/// Opens the manage menu for a group.
///
/// [onEditMembers] adds an "Edit members" action that should open the member
/// picker seeded with the group and save the result (used on the create screen,
/// which owns the picker). [currentSelection] adds "Update to current selection"
/// (used inside the picker, where a live selection already exists). Callers pass
/// whichever edit affordance fits their context.
Future<void> manageGroup(
  BuildContext context,
  WidgetRef ref,
  PlayerGroup group, {
  Future<void> Function()? onEditMembers,
  Set<String>? currentSelection,
}) async {
  final l = AppLocalizations.of(context)!;
  final action = await showModalBottomSheet<_GroupAction>(
    context: context,
    backgroundColor: AppColors.navyBlue,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  l.groupMembersCount(group.memberCount),
                  style: const TextStyle(color: AppColors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline,
                color: AppColors.white),
            title: Text(l.renameGroup,
                style: const TextStyle(color: AppColors.white)),
            onTap: () => Navigator.of(context).pop(_GroupAction.rename),
          ),
          if (onEditMembers != null)
            ListTile(
              leading:
                  const Icon(Icons.group_outlined, color: AppColors.white),
              title: Text(l.editMembers,
                  style: const TextStyle(color: AppColors.white)),
              onTap: () =>
                  Navigator.of(context).pop(_GroupAction.editMembers),
            ),
          if (currentSelection != null)
            ListTile(
              leading:
                  const Icon(Icons.sync_outlined, color: AppColors.white),
              title: Text(l.updateGroupMembers,
                  style: const TextStyle(color: AppColors.white)),
              onTap: () =>
                  Navigator.of(context).pop(_GroupAction.updateMembers),
            ),
          ListTile(
            leading:
                const Icon(Icons.delete_outline, color: AppColors.errorRed),
            title: Text(l.deleteGroup,
                style: const TextStyle(color: AppColors.errorRed)),
            onTap: () => Navigator.of(context).pop(_GroupAction.delete),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return;
  await switch (action) {
    _GroupAction.rename => _renameGroup(context, ref, group),
    _GroupAction.editMembers => onEditMembers!(),
    _GroupAction.updateMembers =>
      saveGroupMembers(context, ref, group, currentSelection!),
    _GroupAction.delete => _deleteGroup(context, ref, group),
  };
}

enum _GroupAction { rename, editMembers, updateMembers, delete }

/// Prompts for a group name; returns the trimmed name, or null if cancelled or
/// left empty.
Future<String?> _showGroupNameDialog(
  BuildContext context, {
  required String title,
  String? initialName,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => _GroupNameDialog(title: title, initialName: initialName),
  );
}

class _GroupNameDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  const _GroupNameDialog({required this.title, this.initialName});

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName ?? '');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final l = AppLocalizations.of(context)!;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l.groupNameRequired);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: AppColors.navyLight,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            BrandedTextField(
              label: l.groupName,
              hint: l.groupNameHint,
              controller: _controller,
              autofocus: true,
              errorText: _error,
              fillColor: AppColors.navyBlue,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l.cancel,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BrandedButton(label: l.save, onPressed: _submit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _showDeleteGroupDialog(BuildContext context, String name) {
  final l = AppLocalizations.of(context)!;
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => Dialog(
      backgroundColor: AppColors.navyLight,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.errorRed.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.errorRed, width: 2),
              ),
              child: const Icon(Icons.delete_outline,
                  color: AppColors.errorRed, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              l.deleteGroupTitle,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.deleteGroupMessage(name),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.grey, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l.cancel,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorRed,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l.delete,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
