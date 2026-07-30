import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_motion.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_choice_chips.dart';
import '../../../../core/widgets/branded_button.dart';
import '../../../../core/widgets/branded_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/domain/entities/user_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/players_providers.dart';

/// Longest membership a coach can grant in one go. A year is well past any
/// real club package, so anything beyond it is a typo.
const int kMaxRenewalDays = 365;

/// Slides up the coach membership sheet for one player: pick a number of days
/// (preset chip or a custom value) and add them **on top of** whatever time is
/// left, with deactivation available as a secondary action.
///
/// Replaces the old activate/deactivate toggle dialog — an active player could
/// not be topped up at all before, because tapping the chip only ever offered
/// "Deactivate".
///
/// Lifetime members never open the sheet: their membership doesn't lapse, so
/// there is nothing to extend.
Future<void> showMembershipSheet(
  BuildContext context, {
  required String uid,
  required String name,
  required DateTime? paidUntil,
  bool isLifetime = false,
}) {
  if (isLifetime) {
    showAppSnackbar(AppLocalizations.of(context)!.lifetimeMember);
    return Future.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.navyLight,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (_) =>
        _MembershipSheet(uid: uid, name: name, paidUntil: paidUntil),
  );
}

/// Which way the chosen days move the expiry.
enum _Mode { add, remove }

class _MembershipSheet extends ConsumerStatefulWidget {
  const _MembershipSheet({
    required this.uid,
    required this.name,
    required this.paidUntil,
  });

  final String uid;
  final String name;
  final DateTime? paidUntil;

  @override
  ConsumerState<_MembershipSheet> createState() => _MembershipSheetState();
}

class _MembershipSheetState extends ConsumerState<_MembershipSheet> {
  /// One-tap amounts: a trial week, a half month, the club's standard month,
  /// and a two-month block. Anything else goes through Custom.
  static const _presets = [7, 14, 30, 60];

  final _formKey = GlobalKey<FormState>();
  final _customController = TextEditingController();

  /// Selected preset, or null when the coach is typing a custom amount.
  int? _preset = 30;

  /// Whether the chosen days are being given or taken back. Only offered for
  /// a player who still has days left — there is nothing to take from an
  /// expired membership.
  _Mode _mode = _Mode.add;

  bool _saving = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  bool get _isActive =>
      widget.paidUntil != null && widget.paidUntil!.isAfter(DateTime.now());

  bool get _removing => _mode == _Mode.remove;

  /// Days the CTA would move the expiry by, unsigned, or null while the custom
  /// field is empty or out of range (which also disables the CTA and blanks
  /// the preview).
  int? get _days {
    if (_preset != null) return _preset;
    final n = int.tryParse(_customController.text.trim());
    if (n == null || n < 1 || n > kMaxRenewalDays) return null;
    return n;
  }

  /// [_days] with the direction applied — what actually goes to the repository.
  int? get _signedDays {
    final days = _days;
    if (days == null) return null;
    return _removing ? -days : days;
  }

  /// Mirrors the datasource: days move the existing expiry, and only an
  /// expired (or absent) membership restarts the clock from today.
  DateTime? get _newExpiry {
    final days = _signedDays;
    if (days == null) return null;
    final now = DateTime.now();
    final base = _isActive ? widget.paidUntil! : now;
    return base.add(Duration(days: days));
  }

  /// True when taking back this many days would consume everything that is
  /// left — the write ends the membership instead of storing a past expiry.
  bool get _willEnd {
    final expiry = _newExpiry;
    return _removing && expiry != null && !expiry.isAfter(DateTime.now());
  }

  Future<void> _apply() async {
    final l = AppLocalizations.of(context)!;
    if (_preset == null && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final days = _signedDays;
    final coach = ref.read(currentUserProvider).value;
    if (days == null || coach == null) return;

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final until = await ref.read(playersRepositoryProvider).adjustMembership(
            widget.uid,
            days: days,
            coachUid: coach.uid,
            coachName: coach.name,
          );
      if (!mounted) return;
      showAppSnackbar(_resultMessage(l, days, until));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackbar(l.unknownError);
    }
  }

  String _resultMessage(AppLocalizations l, int days, DateTime? until) {
    if (until == null) return l.membershipEnded;
    final date = _dateFormat.format(until);
    return days < 0
        ? l.membershipReduced(-days, date)
        : l.membershipExtended(days, date);
  }

  Future<void> _deactivate() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDeleteConfirm(
      context,
      title: l.deactivateMembership,
      message: l.confirmMarkUnpaid(widget.name),
      confirmLabel: l.unpaid,
      cancelLabel: l.cancel,
    );
    if (!confirmed || !mounted) return;

    final coach = ref.read(currentUserProvider).value;
    if (coach == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(playersRepositoryProvider).markUnpaid(
            widget.uid,
            coachUid: coach.uid,
            coachName: coach.name,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackbar(l.unknownError);
    }
  }

  DateFormat get _dateFormat => DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final semantic = context.semanticColors;
    final days = _days;
    final expiry = _newExpiry;

    return Padding(
      // Lift the sheet above the keyboard so the custom-days field stays
      // visible while it is being typed into.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          child: Form(
            key: _formKey,
            // The CTA disables itself on an out-of-range value, so without
            // live validation the coach would get a dead button and no reason.
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l.membershipSheetTitle(widget.name),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _isActive
                      ? l.membershipActiveUntil(
                          UserModel.daysLeftUntil(widget.paidUntil))
                      : l.unpaid,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isActive ? semantic.success : semantic.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  (_isActive ? l.adjustMembership : l.addDays).toUpperCase(),
                  style: AppTextStyles.eyebrow,
                ),
                const SizedBox(height: AppSpacing.md),
                // Only a running membership has days that can be taken back.
                if (_isActive) ...[
                  AppChoiceChips<_Mode>(
                    value: _mode,
                    expanded: true,
                    fillColor: AppColors.navyBlue,
                    onSelected: (v) => setState(() => _mode = v),
                    options: [
                      AppChoiceChipOption(
                        value: _Mode.add,
                        label: l.addDays,
                        icon: Icons.add_rounded,
                      ),
                      AppChoiceChipOption(
                        value: _Mode.remove,
                        label: l.removeDays,
                        icon: Icons.remove_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppChoiceChips<int?>(
                  value: _preset,
                  // navyBlue keeps idle chips readable on the navyLight sheet.
                  fillColor: AppColors.navyBlue,
                  onSelected: (v) => setState(() => _preset = v),
                  options: [
                    for (final d in _presets)
                      AppChoiceChipOption(value: d, label: l.daysShort(d)),
                    AppChoiceChipOption(value: null, label: l.custom),
                  ],
                ),
                if (_preset == null) ...[
                  const SizedBox(height: AppSpacing.md),
                  BrandedTextField(
                    label: l.customDaysLabel,
                    controller: _customController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    fillColor: AppColors.navyBlue,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => Validators.intInRange(
                      v,
                      min: 1,
                      max: kMaxRenewalDays,
                      emptyMsg: l.invalidDayCount,
                      invalidMsg: l.invalidDayCount,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _ExpiryPreview(
                  label: l.newExpiry,
                  // A removal that eats the whole balance shows the outcome in
                  // words rather than a date the write will never store.
                  date: _willEnd
                      ? l.membershipWillEnd
                      : expiry == null
                          ? '—'
                          : _dateFormat.format(expiry),
                  color: _willEnd ? semantic.danger : AppColors.gold,
                  total: _willEnd || expiry == null
                      ? null
                      : l.daysTotal(UserModel.daysLeftUntil(expiry)),
                ),
                const SizedBox(height: AppSpacing.lg),
                BrandedButton(
                  label: days == null
                      ? (_removing ? l.removeDays : l.addDays)
                      : (_removing
                          ? l.removeDaysCta(days)
                          : l.addDaysCta(days)),
                  isLoading: _saving,
                  onPressed: days == null ? null : _apply,
                ),
                if (_isActive)
                  TextButton(
                    onPressed: _saving ? null : _deactivate,
                    child: Text(
                      l.deactivateMembership,
                      style: const TextStyle(
                        color: AppColors.errorRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "what the coach is about to buy" card — the resulting expiry date and
/// the total days the player will then have left.
class _ExpiryPreview extends StatelessWidget {
  const _ExpiryPreview({
    required this.label,
    required this.date,
    required this.color,
    required this.total,
  });

  final String label;
  final String date;

  /// Gold for a date the coach is about to set, red when the adjustment ends
  /// the membership instead.
  final Color color;
  final String? total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.navyBlue,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.sectionHeader),
          const SizedBox(height: AppSpacing.xs),
          AnimatedSwitcher(
            duration: AppMotion.fast,
            child: Text(
              date,
              key: ValueKey(date),
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (total != null) ...[
            const SizedBox(height: 2),
            Text(
              total!,
              style: const TextStyle(color: AppColors.grey, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
