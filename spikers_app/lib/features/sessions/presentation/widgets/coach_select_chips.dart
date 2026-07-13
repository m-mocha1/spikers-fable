import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_choice_chips.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../coaches/presentation/providers/coaches_providers.dart';

/// A wrap of toggleable coach chips, sourced from [coachesProvider] (accounts
/// with role 'coach'). Used in the session-create flows to mark which coaches
/// are available/assigned for a session. The parent owns [selectedIds] and is
/// notified of taps via [onToggle].
class CoachSelectChips extends ConsumerWidget {
  final Set<String> selectedIds;
  final void Function(String uid) onToggle;

  const CoachSelectChips({
    super.key,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final coachesAsync = ref.watch(coachesProvider);

    return coachesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Text(
        l.noCoaches,
        style: const TextStyle(color: AppColors.grey, fontSize: 13),
      ),
      data: (coaches) {
        if (coaches.isEmpty) {
          return Text(
            l.noCoaches,
            style: const TextStyle(color: AppColors.grey, fontSize: 13),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in coaches)
              AppChoiceChip(
                label: c.name.isEmpty ? '?' : c.name,
                selected: selectedIds.contains(c.uid),
                onTap: () => onToggle(c.uid),
              ),
          ],
        );
      },
    );
  }
}
