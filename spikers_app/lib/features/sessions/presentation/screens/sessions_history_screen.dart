import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/title_case.dart';
import '../../../../core/widgets/animations.dart';
import '../../../../core/widgets/gender_filter_chips.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:spikers_app/features/sessions/domain/entities/session_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/sessions_providers.dart';

/// Coach/admin-only gender tag filter; players' lists are already
/// gender-scoped by the history query itself.
final _genderFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');

class SessionsHistoryScreen extends ConsumerStatefulWidget {
  const SessionsHistoryScreen({super.key});

  @override
  ConsumerState<SessionsHistoryScreen> createState() =>
      _SessionsHistoryScreenState();
}

class _SessionsHistoryScreenState
    extends ConsumerState<SessionsHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Best-effort: archives anything the 15-min sessionCleanup cron hasn't
    // caught yet so the page is as fresh as possible. Never throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionsRepositoryProvider).archiveExpiredNow();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final historyAsync = ref.watch(sessionsHistoryProvider);
    final isCoach = ref.watch(currentUserProvider).value?.isCoach ?? false;
    final genderFilter = ref.watch(_genderFilterProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.sessionsHistory)),
      body: historyAsync.when(
        loading: () => const ListShimmer(itemHeight: 110),
        error: (e, _) => ErrorView(
            onRetry: () => ref.invalidate(sessionsHistoryProvider)),
        data: (sessions) {
          final filtered = !isCoach || genderFilter == 'all'
              ? sessions
              : sessions.where((s) => s.gender == genderFilter).toList();

          final Widget list = filtered.isEmpty
              ? EmptyStateView(icon: Icons.history, title: l.noSessionsHistory)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => AppStaggeredItem(
                    index: i,
                    child: _HistoryCard(session: filtered[i]),
                  ),
                );

          // Players' lists are already gender-scoped by the query, so only
          // coaches/admins get the tag filter.
          if (!isCoach) return list;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: GenderFilterChips(
                    value: genderFilter,
                    onChanged: (v) =>
                        ref.read(_genderFilterProvider.notifier).state = v,
                  ),
                ),
              ),
              Expanded(child: list),
            ],
          );
        },
      ),
    );
  }
}

class _AvatarData {
  final String name;
  final String photoUrl;
  const _AvatarData({required this.name, required this.photoUrl});
}

class _HistoryCard extends ConsumerStatefulWidget {
  final SessionModel session;
  const _HistoryCard({required this.session});

  @override
  ConsumerState<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends ConsumerState<_HistoryCard> {
  static const _maxVisible = 4;
  static const _avatarRadius = 14.0;
  static const _avatarOverlap = 18.0;

  List<_AvatarData> _avatars = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAvatars();
  }

  Future<void> _loadAvatars() async {
    final attended = widget.session.attendedIds;
    if (attended.isEmpty) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    final ids = attended.take(_maxVisible).toList();
    try {
      // Cached variant: avatars tolerate staleness, and the same players
      // recur across history cards — only never-seen uids hit Firestore.
      final profiles = await ref
          .read(sessionsRepositoryProvider)
          .fetchPublicProfilesCached(ids);
      // Preserve attendedIds order so avatars don't reshuffle by doc order.
      final ordered = [
        for (final uid in ids)
          if (profiles.containsKey(uid))
            _AvatarData(
              name: profiles[uid]!.name,
              photoUrl: profiles[uid]!.photoUrl,
            ),
      ];
      if (mounted) {
        setState(() {
          _avatars = ordered;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final fmt = DateFormat('MMM d, HH:mm');
    final session = widget.session;

    return Pressable(
      onTap: () => context.push(Routes.sessionDetail, extra: session),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.navyLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 13, color: AppColors.grey),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(session.location.toTitleCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.grey, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Text('· ${fmt.format(session.startTime)}',
                    style:
                        const TextStyle(color: AppColors.grey, fontSize: 12)),
              ],
            ),
            if (session.attendedIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildAvatarRow(),
            ],
            const SizedBox(height: 6),
            Text(
              l.historyAttendanceSummary(
                session.attendedIds.length,
                session.attendeeIds.length,
                session.maxPlayers,
              ),
              style: const TextStyle(color: AppColors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarRow() {
    const diameter = _avatarRadius * 2;
    if (!_loaded) {
      return const SizedBox(height: diameter);
    }

    final total = widget.session.attendedIds.length;
    final overflow = total - _avatars.length;
    final showOverflow = overflow > 0;
    final slots = _avatars.length + (showOverflow ? 1 : 0);
    final width = slots == 0
        ? 0.0
        : diameter + (slots - 1) * (diameter - (diameter - _avatarOverlap));

    return SizedBox(
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < _avatars.length; i++)
            Positioned(
              left: i * _avatarOverlap,
              child: _avatarCircle(_avatars[i]),
            ),
          if (showOverflow)
            Positioned(
              left: _avatars.length * _avatarOverlap,
              child: _overflowCircle(overflow),
            ),
          // Reserve horizontal space so the stack participates in layout.
          SizedBox(width: width),
        ],
      ),
    );
  }

  Widget _avatarCircle(_AvatarData a) {
    final initials = a.name.trim().isEmpty
        ? '?'
        : a.name
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.navyLight, width: 2),
      ),
      child: CircleAvatar(
        radius: _avatarRadius,
        backgroundColor: AppColors.gold.withValues(alpha: 0.2),
        backgroundImage: a.photoUrl.isNotEmpty
            ? CachedNetworkImageProvider(a.photoUrl)
            : null,
        child: a.photoUrl.isEmpty
            ? Text(initials,
                style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 10))
            : null,
      ),
    );
  }

  Widget _overflowCircle(int n) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.navyLight, width: 2),
      ),
      child: CircleAvatar(
        radius: _avatarRadius,
        backgroundColor: AppColors.navyBlue,
        child: Text('+$n',
            style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
                fontSize: 10)),
      ),
    );
  }
}
