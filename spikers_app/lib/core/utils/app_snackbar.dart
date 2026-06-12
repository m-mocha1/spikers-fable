import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Attached to MaterialApp so snackbars survive navigation (the old
/// Get.snackbar rendered into a global overlay; this is the Material
/// equivalent without needing a BuildContext at the call site).
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showAppSnackbar(String message,
    {Duration duration = const Duration(seconds: 3)}) {
  rootScaffoldMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: AppColors.white)),
      backgroundColor: AppColors.navyLight,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
}
