import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';

class CoachesTab extends StatefulWidget {
  const CoachesTab({super.key});

  @override
  State<CoachesTab> createState() => _CoachesTabState();
}

class _CoachesTabState extends State<CoachesTab> {
  List<Map<String, dynamic>> _coaches = [];
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
        .collection('users_public')
        .where('role', isEqualTo: 'coach')
        .snapshots()
        .listen((snap) {
      final docs = snap.docs.toList()
        ..sort((a, b) => ((a.data()['name'] ?? '') as String)
            .compareTo((b.data()['name'] ?? '') as String));

      if (!mounted) return;
      setState(() {
        _coaches = docs.map((d) {
          final data = d.data();
          return {
            'uid': d.id,
            'name': (data['name'] ?? '') as String,
            'photoUrl': (data['photoUrl'] ?? '') as String,
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

    if (_coaches.isEmpty) {
      return Center(
        child: Text(l.noCoaches,
            style: const TextStyle(color: AppColors.grey, fontSize: 15)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _coaches.length,
      itemBuilder: (_, i) => _CoachCard(coach: _coaches[i]),
    );
  }
}

class _CoachCard extends StatelessWidget {
  final Map<String, dynamic> coach;
  const _CoachCard({required this.coach});

  @override
  Widget build(BuildContext context) {
    final name = coach['name'] as String;
    final photoUrl = coach['photoUrl'] as String;

    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.navyLight,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.gold.withValues(alpha: 0.2),
              backgroundImage: photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
              child: photoUrl.isEmpty
                  ? Text(initials,
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 22))
                  : null,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 19)),
            ),
          ],
        ),
      ),
    );
  }
}
