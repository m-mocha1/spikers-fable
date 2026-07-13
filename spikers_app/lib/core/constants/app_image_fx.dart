import 'package:flutter/widgets.dart';

/// Image colour-matrix filters kept in one place so screens don't hand-roll
/// magic matrices inline.
class AppImageFx {
  AppImageFx._();

  /// A gentle contrast + brightness lift for the session card artwork on the
  /// sessions screen. The card designs are deliberately dark (navy background,
  /// thin gold linework), so on their own they read low-contrast; this pushes
  /// the shadows down and the gold up so the art pops — without editing the
  /// source assets. Deliberately mild (contrast ≈ 1.15) to avoid a processed,
  /// over-saturated look. The session-detail hero keeps the plain (dimmed) art.
  static const ColorFilter cardArtPop = ColorFilter.matrix(<double>[
    1.15, 0, 0, 0, -13, //
    0, 1.15, 0, 0, -13, //
    0, 0, 1.15, 0, -13, //
    0, 0, 0, 1, 0, //
  ]);
}
