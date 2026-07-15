import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:spikers_app/features/auth/domain/entities/user_model.dart';

/// Coach-facing roster row (from the full users collection).
class PlayerSummary {
  final String uid;
  final String name;

  /// 'male' or 'female'; null when the player never provided one (gender is
  /// optional at registration — App Store guideline 5.1.1(v)). Never defaulted:
  /// a genderless player must not silently count as male in filters or exports.
  final String? gender;
  final String photoUrl;
  final DateTime? dateOfBirth;
  final DateTime? createdAt;
  final int attendanceCount;
  final DateTime? paidUntil;
  final bool lifetimeMember;
  final bool injured;

  const PlayerSummary({
    required this.uid,
    required this.name,
    required this.gender,
    required this.photoUrl,
    required this.dateOfBirth,
    required this.createdAt,
    required this.attendanceCount,
    required this.paidUntil,
    required this.lifetimeMember,
    required this.injured,
  });

  bool get isPaid =>
      lifetimeMember ||
      (paidUntil != null && paidUntil!.isAfter(DateTime.now()));

  int get paymentDaysLeft => UserModel.daysLeftUntil(paidUntil);

  factory PlayerSummary.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return PlayerSummary(
      uid: doc.id,
      name: (d['name'] ?? '') as String,
      gender: d['gender'] as String?,
      photoUrl: (d['photoUrl'] ?? '') as String,
      dateOfBirth: (d['dateOfBirth'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      attendanceCount: ((d['attendanceCount'] ?? 0) as num).toInt(),
      paidUntil: (d['paidUntil'] as Timestamp?)?.toDate(),
      lifetimeMember: (d['lifetimeMember'] ?? false) as bool,
      injured: (d['injured'] ?? false) as bool,
    );
  }
}

/// Player-facing roster row (from the public mirror; no payment data).
class PeerSummary {
  final String uid;
  final String name;
  final String photoUrl;
  final int attendanceCount;
  final bool injured;

  const PeerSummary({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.attendanceCount,
    required this.injured,
  });

  factory PeerSummary.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return PeerSummary(
      uid: doc.id,
      name: (d['name'] ?? '') as String,
      photoUrl: (d['photoUrl'] ?? '') as String,
      attendanceCount: ((d['attendanceCount'] ?? 0) as num).toInt(),
      injured: (d['injured'] ?? false) as bool,
    );
  }
}
