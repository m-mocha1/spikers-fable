import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/session_model.dart';
import '../../routes/app_routes.dart';

class SessionsHistoryScreen extends StatefulWidget {
  const SessionsHistoryScreen({super.key});

  @override
  State<SessionsHistoryScreen> createState() => _SessionsHistoryScreenState();
}

class _SessionsHistoryScreenState extends State<SessionsHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _archiveNow());
  }

  Future<void> _archiveNow() async {
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('archiveExpiredSessionsNow')
          .call();
    } catch (_) {
      // Silent: page still renders any existing history. The 15-min
      // sessionCleanup cron will catch anything missed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.sessionsHistory)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sessions_history')
            .orderBy('endTime', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.gold));
          }
          if (snap.hasError) {
            return Center(
              child: Text(l.errorOccurred,
                  style: const TextStyle(
                      color: AppColors.grey, fontSize: 15)),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(l.noSessionsHistory,
                  style: const TextStyle(
                      color: AppColors.grey, fontSize: 15)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            itemCount: docs.length,
            itemBuilder: (_, i) =>
                _HistoryCard(session: SessionModel.fromDoc(docs[i])),
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

class _HistoryCard extends StatefulWidget {
  final SessionModel session;
  const _HistoryCard({required this.session});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
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
      final snap = await FirebaseFirestore.instance
          .collection('users_public')
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      // Preserve attendedIds order so avatars don't reshuffle by doc order.
      final byId = {
        for (final d in snap.docs)
          d.id: _AvatarData(
            name: (d.data()['name'] ?? '') as String,
            photoUrl: (d.data()['photoUrl'] ?? '') as String,
          ),
      };
      final ordered = [
        for (final uid in ids)
          if (byId.containsKey(uid)) byId[uid]!,
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

    return GestureDetector(
      onTap: () => Get.toNamed(Routes.sessionDetail, arguments: session),
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
                child: Text(session.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.grey, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Text('· ${fmt.format(session.startTime)}',
                  style: const TextStyle(
                      color: AppColors.grey, fontSize: 12)),
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
            style: const TextStyle(
                color: AppColors.grey, fontSize: 12),
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
        : a.name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();
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
