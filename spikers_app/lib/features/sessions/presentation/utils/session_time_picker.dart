import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';

/// The one place the session date/time picker's options live, shared by the
/// create-session form and the reschedule dialog: 24-hour, no seconds, 5-minute
/// steps, and a window of [now - 1min, now + 365 days].
///
/// The upper bound is deliberately the same year that `updateSessionTime`'s
/// MAX_RESCHEDULE_AHEAD_MS enforces server-side — keeping both in one place per
/// side is what stops the picker from offering a date the callable will reject.
///
/// Returns null when the picker is dismissed.
Future<DateTime?> pickSessionDateTime(
  BuildContext context, {
  required DateTime initial,
}) =>
    showOmniDateTimePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(minutes: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      is24HourMode: true,
      isShowSeconds: false,
      minutesInterval: 5,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
    );

/// Display format for a picked session date+time, shared by the same two call
/// sites so a rescheduled session reads exactly like a freshly created one.
final sessionDateTimeFormat = DateFormat('MMM d, yyyy  HH:mm');
