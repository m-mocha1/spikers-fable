class AppAssets {
  static const logo        = 'assets/images/logo.png';
  static const splashBg    = 'assets/images/startUpScreen.png';

  /// Session card art, in the order shown to admins in the art picker (card 1
  /// is index 0). Keep this list and its length in sync with CARD_DESIGN_COUNT
  /// in functions/src/index.ts, which the recurring-session job reads.
  static const cardDesigns = <String>[
    'assets/images/cards/card_a_trajectory.jpeg',
    'assets/images/cards/card_b_netCat.jpeg',
    'assets/images/cards/card_c_ball.jpeg',
    'assets/images/cards/card_d_medel.jpeg',
    'assets/images/cards/card_e_court.jpeg',
    'assets/images/cards/card_f_kit.jpeg',
    'assets/images/cards/card_g_basket.jpeg',
    'assets/images/cards/card_h_crow.jpeg',
  ];

  /// Ascending badge art for the games-played tiers, indexed by
  /// [AttendanceTiers.tierIndex] (0..4).
  static const gamesPlayedBadges = <String>[
    'assets/images/gamesPlayed_levels/lvl1.png',
    'assets/images/gamesPlayed_levels/lvl2.png',
    'assets/images/gamesPlayed_levels/lvl3.png',
    'assets/images/gamesPlayed_levels/lvl4.png',
    'assets/images/gamesPlayed_levels/lvl5.png',
  ];

  /// Ascending badge art for the endorsement levels, indexed by
  /// `endorsementLevel(count) - 1` (levels 1..5).
  static const endorsementBadges = <String>[
    'assets/images/endorsment_levels/lvl1.png',
    'assets/images/endorsment_levels/lvl2.png',
    'assets/images/endorsment_levels/lvl3.png',
    'assets/images/endorsment_levels/lvl4.png',
    'assets/images/endorsment_levels/lvl5.png',
  ];
}
