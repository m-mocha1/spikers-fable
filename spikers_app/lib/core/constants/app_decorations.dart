import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Shared surface decorations, so screens that sit side by side (session
/// detail, the line-up) draw their panels identically instead of hand-rolling
/// near-copies.
class AppDecorations {
  AppDecorations._();

  /// The standard content panel: plain navy body, hairline border and layered
  /// shadows — the list card's premium treatment without the art.
  static BoxDecoration panel() => BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      );
}
