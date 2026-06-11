import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../widgets/profile_info.dart';
import 'payment_confirm_dialog.dart';

class PlayerProfileScreen extends StatelessWidget {
  const PlayerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final userId = Get.arguments as String?;

    if (userId == null || userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(l.unknownError,
              style: const TextStyle(color: AppColors.grey)),
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
                child: CircularProgressIndicator(color: AppColors.gold)),
          );
        }

        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(l.errorOccurred,
                  style: const TextStyle(color: AppColors.grey)),
            ),
          );
        }

        if (!snap.hasData || !snap.data!.exists) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(l.noPlayers,
                  style: const TextStyle(color: AppColors.grey)),
            ),
          );
        }

        final user = UserModel.fromDoc(snap.data!);

        return Scaffold(
          appBar: AppBar(
            title: Text(user.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _ReadOnlyAvatar(name: user.name, photoUrl: user.photoUrl),
                const SizedBox(height: 16),
                Text(user.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ProfileRoleBadge(isCoach: user.isCoach, l: l),
                const SizedBox(height: 24),
                ProfileStatsRow(user: user, l: l),
                const SizedBox(height: 16),
                ProfileInfoCard(user: user, l: l),
                if (!user.isCoach && !user.lifetimeMember) ...[
                  const SizedBox(height: 24),
                  _PaymentActionButton(user: user, l: l),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReadOnlyAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  const _ReadOnlyAvatar({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .split(' ')
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();

    return CircleAvatar(
      radius: 64,
      backgroundColor: AppColors.gold,
      backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
          ? CachedNetworkImageProvider(photoUrl!)
          : null,
      child: (photoUrl == null || photoUrl!.isEmpty)
          ? Text(
              initials,
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyBlue),
            )
          : null,
    );
  }
}

class _PaymentActionButton extends StatelessWidget {
  final UserModel user;
  final AppLocalizations l;
  const _PaymentActionButton({required this.user, required this.l});

  @override
  Widget build(BuildContext context) {
    final markingPaid = !user.isPaid;
    final color = markingPaid ? AppColors.success : AppColors.errorRed;
    final icon = markingPaid
        ? Icons.check_circle_outline
        : Icons.highlight_off_rounded;
    final label = markingPaid ? l.paid : l.unpaid;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => confirmTogglePayment(
          context,
          uid: user.uid,
          name: user.name,
          paidUntil: user.paidUntil,
        ),
        icon: Icon(icon, color: AppColors.white),
        label: Text(label,
            style: const TextStyle(
                color: AppColors.white, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
