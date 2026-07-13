import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Semantic status colors and the standard translucent fills used for chips,
/// pills and tinted containers on the navy background (Premium Pass Phase 0).
///
/// Registered on [ThemeData.extensions] in `app_theme.dart`; read it with
/// `context.semanticColors` (see [AppSemanticColorsX]).
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.successFill,
    required this.warningFill,
    required this.dangerFill,
    required this.goldFill,
    required this.surfaceFill,
  });

  /// Positive state — confirmations, active membership, healthy capacity.
  final Color success;

  /// Caution state — expiring membership, nearly full capacity.
  final Color warning;

  /// Destructive or error state — full capacity, remove/cancel actions.
  final Color danger;

  /// Translucent [success] fill for chips/containers in that state.
  final Color successFill;

  /// Translucent [warning] fill for chips/containers in that state.
  final Color warningFill;

  /// Translucent [danger] fill for chips/containers in that state.
  final Color dangerFill;

  /// Brand-gold translucent fill for selected / highlighted chips.
  final Color goldFill;

  /// Neutral white-on-navy fill for idle chips, tiles and inset surfaces.
  final Color surfaceFill;

  /// The app's single (dark navy) palette. Fill alphas match the values
  /// screens already use: gold/status fills at 15%, neutral fills at 8%.
  static final dark = AppSemanticColors(
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.errorRed,
    successFill: AppColors.success.withValues(alpha: 0.15),
    warningFill: AppColors.warning.withValues(alpha: 0.15),
    dangerFill: AppColors.errorRed.withValues(alpha: 0.15),
    goldFill: AppColors.gold.withValues(alpha: 0.15),
    surfaceFill: AppColors.white.withValues(alpha: 0.08),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? successFill,
    Color? warningFill,
    Color? dangerFill,
    Color? goldFill,
    Color? surfaceFill,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      successFill: successFill ?? this.successFill,
      warningFill: warningFill ?? this.warningFill,
      dangerFill: dangerFill ?? this.dangerFill,
      goldFill: goldFill ?? this.goldFill,
      surfaceFill: surfaceFill ?? this.surfaceFill,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      successFill: Color.lerp(successFill, other.successFill, t)!,
      warningFill: Color.lerp(warningFill, other.warningFill, t)!,
      dangerFill: Color.lerp(dangerFill, other.dangerFill, t)!,
      goldFill: Color.lerp(goldFill, other.goldFill, t)!,
      surfaceFill: Color.lerp(surfaceFill, other.surfaceFill, t)!,
    );
  }
}

/// Shortcut so call sites read `context.semanticColors.success`.
extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
