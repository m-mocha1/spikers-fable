import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/age_calculator.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';
import '../players/payment_confirm_dialog.dart';

class PlayersTab extends StatefulWidget {
  const PlayersTab({super.key});

  @override
  State<PlayersTab> createState() => _PlayersTabState();
}

class _PlayersTabState extends State<PlayersTab> {
  String _genderFilter = 'all';
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
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'player')
        .snapshots()
        .listen((snap) {
      final docs = snap.docs.toList()
        ..sort((a, b) => ((a.data()['name'] ?? '') as String)
            .compareTo((b.data()['name'] ?? '') as String));

      if (!mounted) return;
      setState(() {
        _players = docs.map((d) {
          final data = d.data();
          return {
            'uid': d.id,
            'name': (data['name'] ?? '') as String,
            'gender': (data['gender'] ?? 'male') as String,
            'photoUrl': (data['photoUrl'] ?? '') as String,
            'dateOfBirth': data['dateOfBirth'] as Timestamp?,
            'attendanceCount':
                ((data['attendanceCount'] ?? 0) as num).toInt(),
            'paidUntil': data['paidUntil'] as Timestamp?,
            'paidAt': data['paidAt'] as Timestamp?,
            'lifetimeMember': (data['lifetimeMember'] ?? false) as bool,
          };
        }).toList();
        _loading = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_genderFilter == 'all') return _players;
    return _players.where((p) => p['gender'] == _genderFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }

    final filtered = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              _Chip(
                label: l.allGenders,
                active: _genderFilter == 'all',
                onTap: () => setState(() => _genderFilter = 'all'),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: l.male,
                active: _genderFilter == 'male',
                onTap: () => setState(() => _genderFilter = 'male'),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: l.female,
                active: _genderFilter == 'female',
                onTap: () => setState(() => _genderFilter = 'female'),
              ),
              const Spacer(),
              Text(
                '${filtered.length}',
                style: const TextStyle(color: AppColors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(l.noPlayers,
                      style: const TextStyle(
                          color: AppColors.grey, fontSize: 15)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final dob = filtered[i]['dateOfBirth'] as Timestamp?;
                    final player = filtered[i];
                    return _PlayerCard(
                      player: player,
                      age: dob == null
                          ? 0
                          : AgeCalculator.fromDate(dob.toDate()),
                      l: l,
                      onTapBadge: () => confirmTogglePayment(
                        context,
                        uid: player['uid'] as String,
                        name: player['name'] as String,
                        paidUntil:
                            (player['paidUntil'] as Timestamp?)?.toDate(),
                        isLifetime:
                            player['lifetimeMember'] as bool,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final Map<String, dynamic> player;
  final int age;
  final AppLocalizations l;
  final VoidCallback onTapBadge;
  const _PlayerCard({
    required this.player,
    required this.age,
    required this.l,
    required this.onTapBadge,
  });

  @override
  Widget build(BuildContext context) {
    final name = player['name'] as String;
    final gender = player['gender'] as String;
    final photoUrl = player['photoUrl'] as String;
    final count = player['attendanceCount'] as int;
    final paidUntilTs = player['paidUntil'] as Timestamp?;
    final paidUntil = paidUntilTs?.toDate();
    final isLifetime = player['lifetimeMember'] as bool;
    final isPaid =
        isLifetime || (paidUntil != null && paidUntil.isAfter(DateTime.now()));
    final daysLeft = UserModel.daysLeftUntil(paidUntil);

    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Get.toNamed(
            Routes.playerProfile,
            arguments: player['uid'],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      gender == 'male' ? Icons.male : Icons.female,
                      color:
                          gender == 'male' ? AppColors.gold : Colors.pinkAccent,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('$age ${l.years}',
                        style: const TextStyle(
                            color: AppColors.grey, fontSize: 12)),
                    const SizedBox(width: 10),
                    const Icon(Icons.sports_volleyball,
                        size: 11, color: AppColors.grey),
                    const SizedBox(width: 3),
                    Text('$count ${l.sessionsAttended}',
                        style: const TextStyle(
                            color: AppColors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _PaidBadge(
            isPaid: isPaid,
            daysLeft: daysLeft,
            isLifetime: isLifetime,
            onTap: onTapBadge,
            l: l,
          ),
        ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaidBadge extends StatelessWidget {
  final bool isPaid;
  final int daysLeft;
  final bool isLifetime;
  final VoidCallback onTap;
  final AppLocalizations l;
  const _PaidBadge({
    required this.isPaid,
    required this.daysLeft,
    required this.isLifetime,
    required this.onTap,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (isLifetime) {
      color = AppColors.gold;
    } else if (!isPaid || daysLeft == 0) {
      color = AppColors.errorRed;
    } else if (daysLeft <= 9) {
      color = AppColors.warning;
    } else {
      color = AppColors.success;
    }
    final showDays = !isLifetime && isPaid && daysLeft <= 9;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isLifetime ? l.lifetime : (isPaid ? l.paid : l.unpaid),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            if (showDays)
              Text(
                l.daysLeft(daysLeft),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.gold : AppColors.navyLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? AppColors.gold : AppColors.grey),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.navyBlue : AppColors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
