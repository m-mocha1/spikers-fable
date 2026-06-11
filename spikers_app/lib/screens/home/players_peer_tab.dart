import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/auth_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

class PlayersPeerTab extends StatefulWidget {
  const PlayersPeerTab({super.key});

  @override
  State<PlayersPeerTab> createState() => _PlayersPeerTabState();
}

class _PlayersPeerTabState extends State<PlayersPeerTab> {
  List<Map<String, dynamic>> _players = [];
  bool _loading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _listen() {
    final me = Get.find<AuthController>().currentUser.value;
    if (me == null) {
      setState(() => _loading = false);
      return;
    }
    final myUid = me.uid;
    final myGender = me.gender;

    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('users_public')
        .where('role', isEqualTo: 'player')
        .where('gender', isEqualTo: myGender)
        .snapshots()
        .listen((snap) {
      final docs = snap.docs.where((d) => d.id != myUid).toList()
        ..sort((a, b) => ((a.data()['name'] ?? '') as String)
            .compareTo((b.data()['name'] ?? '') as String));

      if (!mounted) return;
      setState(() {
        _players = docs.map((d) {
          final data = d.data();
          return {
            'uid': d.id,
            'name': (data['name'] ?? '') as String,
            'photoUrl': (data['photoUrl'] ?? '') as String,
            'attendanceCount':
                ((data['attendanceCount'] ?? 0) as num).toInt(),
          };
        }).toList();
        _loading = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }

    if (_players.isEmpty) {
      return Center(
        child: Text(l.noPlayers,
            style: const TextStyle(color: AppColors.grey, fontSize: 15)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _players.length,
      itemBuilder: (_, i) => _PeerCard(player: _players[i], l: l),
    );
  }
}

class _PeerCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final AppLocalizations l;
  const _PeerCard({required this.player, required this.l});

  @override
  Widget build(BuildContext context) {
    final name = player['name'] as String;
    final photoUrl = player['photoUrl'] as String;
    final count = player['attendanceCount'] as int;

    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.gold.withValues(alpha: 0.2),
            backgroundImage: photoUrl.isNotEmpty
                ? CachedNetworkImageProvider(photoUrl)
                : null,
            child: photoUrl.isEmpty
                ? Text(initials,
                    style: const TextStyle(
                        color: AppColors.gold, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.sports_volleyball,
                        size: 11, color: AppColors.grey),
                    const SizedBox(width: 4),
                    Text('$count ${l.sessionsAttended}',
                        style: const TextStyle(
                            color: AppColors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
