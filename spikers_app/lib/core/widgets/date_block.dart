import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';

/// Ticket-corner date block: big day-of-month over a small gold month, on a
/// translucent navy tile so it reads as printed on the event art.
///
/// Shared between the session cards and the session detail header; [scale]
/// bumps the whole tile up proportionally for hero placements.
class DateBlock extends StatelessWidget {
  final DateTime date;
  final double scale;
  const DateBlock(this.date, {super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54 * scale,
      padding: EdgeInsets.symmetric(vertical: 8 * scale),
      decoration: BoxDecoration(
        color: AppColors.navyDeep.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('d').format(date),
            style: TextStyle(
              fontSize: 20 * scale,
              fontWeight: FontWeight.w800,
              color: AppColors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            DateFormat('MMM').format(date).toUpperCase(),
            style: TextStyle(
              fontSize: 10.5 * scale,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
