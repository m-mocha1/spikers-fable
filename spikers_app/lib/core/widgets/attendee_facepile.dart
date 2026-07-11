import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import 'package:spikers_app/features/sessions/domain/repositories/sessions_repository.dart'
    show PublicProfile;
import 'package:spikers_app/features/sessions/presentation/providers/sessions_providers.dart';

/// Overlapping attendee avatars — makes a card read as *people playing*, not
/// just a capacity number. Overflow is shown as a "+N" dot styled like the
/// faces so the pile reads as one continuous strip. Renders nothing while the
/// profile fetch is in flight or when the session is empty.
///
/// Shared between the session cards and the Next-Up spotlight; [ringColor]
/// should match the surface the pile sits on so stacked faces separate cleanly.
class AttendeeFacepile extends ConsumerWidget {
  final List<String> uids;
  final Color ringColor;
  const AttendeeFacepile(
    this.uids, {
    super.key,
    this.ringColor = AppColors.navyLight,
  });

  static const _maxFaces = 3;
  static const double _diameter = 28;
  static const double _step = 19;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (uids.isEmpty) return const SizedBox.shrink();
    final shown = uids.take(_maxFaces).join(',');
    final profiles = ref.watch(facepileProfilesProvider(shown)).value;
    if (profiles == null || profiles.isEmpty) return const SizedBox.shrink();
    final extra = uids.length - profiles.length;
    final dots = profiles.length + (extra > 0 ? 1 : 0);

    return SizedBox(
      width: _diameter + _step * (dots - 1),
      height: _diameter,
      child: Stack(
        children: [
          for (var i = 0; i < profiles.length; i++)
            PositionedDirectional(
              start: i * _step,
              child: _FaceDot(profiles[i], ringColor: ringColor),
            ),
          if (extra > 0)
            PositionedDirectional(
              start: profiles.length * _step,
              child: _OverflowDot(extra, ringColor: ringColor),
            ),
        ],
      ),
    );
  }
}

class _FaceDot extends StatelessWidget {
  final PublicProfile profile;
  final Color ringColor;
  const _FaceDot(this.profile, {required this.ringColor});

  @override
  Widget build(BuildContext context) {
    final initial =
        profile.name.trim().isEmpty ? '?' : profile.name.trim()[0].toUpperCase();
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Ring in the surface colour so stacked faces separate cleanly.
        border: Border.all(color: ringColor, width: 2),
      ),
      child: CircleAvatar(
        radius: 12,
        backgroundColor: AppColors.gold.withValues(alpha: 0.25),
        backgroundImage: profile.photoUrl.isNotEmpty
            ? CachedNetworkImageProvider(profile.photoUrl)
            : null,
        child: profile.photoUrl.isEmpty
            ? Text(
                initial,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }
}

/// "+N" rendered as one more dot in the pile instead of loose text.
class _OverflowDot extends StatelessWidget {
  final int count;
  final Color ringColor;
  const _OverflowDot(this.count, {required this.ringColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2),
      ),
      child: CircleAvatar(
        radius: 12,
        backgroundColor: AppColors.navyDeep.withValues(alpha: 0.85),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text(
              '+$count',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
