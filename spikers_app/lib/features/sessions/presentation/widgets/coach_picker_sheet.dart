import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/branded_button.dart';
import '../../../../l10n/app_localizations.dart';
import 'coach_select_chips.dart';

/// Opens a modal bottom sheet that lets a coach change which coaches are
/// marked available for a session. Returns the chosen uid set, or null if
/// dismissed without confirming. [initial] pre-selects the current list.
///
/// Deliberately smaller than [showMemberPicker]: a club has a handful of
/// coaches, so this is a chip wrap with no search, filters or group rail.
Future<Set<String>?> showCoachPicker(
  BuildContext context, {
  required Set<String> initial,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navyBlue,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (_) => _CoachPickerSheet(initial: initial),
  );
}

class _CoachPickerSheet extends ConsumerStatefulWidget {
  final Set<String> initial;
  const _CoachPickerSheet({required this.initial});

  @override
  ConsumerState<_CoachPickerSheet> createState() => _CoachPickerSheetState();
}

class _CoachPickerSheetState extends ConsumerState<_CoachPickerSheet> {
  late final Set<String> _selected = {...widget.initial};

  void _toggle(String uid) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.add(uid)) _selected.remove(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return SafeArea(
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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.chooseCoaches,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  l.coachesCount(_selected.length),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // The chip wrap sizes to its content, but stays scrollable so a long
          // roster can never push the Done button off screen.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: SizedBox(
                width: double.infinity,
                child: CoachSelectChips(
                  selectedIds: _selected,
                  onToggle: _toggle,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: BrandedButton(
              label: l.done,
              onPressed: () => Navigator.of(context).pop(_selected),
            ),
          ),
        ],
      ),
    );
  }
}
