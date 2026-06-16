import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/age_calculator.dart';

class UserModel {
  final String uid;
  final String name;
  // gender and dateOfBirth are optional: registration no longer requires them
  // (App Store guideline 5.1.1(v)). Null means "not provided".
  final String? gender;
  final DateTime? dateOfBirth;
  final String role;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final DateTime? paidUntil;
  final DateTime? paidAt;
  final int? heightCm;
  final int? weightKg;
  final DateTime? lastSeenAnnouncementsAt;
  final bool lifetimeMember;

  const UserModel({
    required this.uid,
    required this.name,
    this.gender,
    this.dateOfBirth,
    required this.role,
    this.photoUrl,
    required this.createdAt,
    this.verifiedAt,
    this.paidUntil,
    this.paidAt,
    this.heightCm,
    this.weightKg,
    this.lastSeenAnnouncementsAt,
    this.lifetimeMember = false,
  });

  /// Age in years, or null when no date of birth has been provided.
  int? get age =>
      dateOfBirth == null ? null : AgeCalculator.fromDate(dateOfBirth!);
  bool get isAdmin => role == 'admin';
  // Admins inherit all coach abilities, so coach-gated UI also covers admins.
  bool get isCoach => role == 'coach' || role == 'admin';
  bool get isPaid =>
      lifetimeMember ||
      (paidUntil != null && paidUntil!.isAfter(DateTime.now()));
  // Sessions are gender-segregated and age-gated, so both fields are required
  // before we can match a player to sessions. Gating only this feature (not
  // registration) keeps us within App Store guideline 5.1.1(v).
  bool get hasCompleteProfile => gender != null && dateOfBirth != null;
  int get paymentDaysLeft => daysLeftUntil(paidUntil);

  // Calendar-day diff so a sub expiring tomorrow at any hour reads as
  // "1 day left", not "0 days left" from Duration.inDays truncation.
  static int daysLeftUntil(DateTime? paidUntil) {
    if (paidUntil == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay =
        DateTime(paidUntil.year, paidUntil.month, paidUntil.day);
    final diff = endDay.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: d['name'] ?? '',
      gender: d['gender'] as String?,
      dateOfBirth: (d['dateOfBirth'] as Timestamp?)?.toDate(),
      role: d['role'] ?? 'player',
      photoUrl: d['photoUrl'] as String?,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      verifiedAt: (d['verifiedAt'] as Timestamp?)?.toDate(),
      paidUntil: (d['paidUntil'] as Timestamp?)?.toDate(),
      paidAt: (d['paidAt'] as Timestamp?)?.toDate(),
      heightCm: (d['heightCm'] as num?)?.toInt(),
      weightKg: (d['weightKg'] as num?)?.toInt(),
      lastSeenAnnouncementsAt:
          (d['lastSeenAnnouncementsAt'] as Timestamp?)?.toDate(),
      lifetimeMember: (d['lifetimeMember'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (gender != null) 'gender': gender,
        if (dateOfBirth != null)
          'dateOfBirth': Timestamp.fromDate(dateOfBirth!),
        'role': role,
        'createdAt': Timestamp.fromDate(createdAt),
        // Written explicitly (even as null) so cleanupUnverifiedUsers can
        // query `where verifiedAt == null` — Firestore's null equality does
        // not match missing fields.
        'verifiedAt':
            verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
        if (paidUntil != null) 'paidUntil': Timestamp.fromDate(paidUntil!),
        if (paidAt != null) 'paidAt': Timestamp.fromDate(paidAt!),
        if (heightCm != null) 'heightCm': heightCm,
        if (weightKg != null) 'weightKg': weightKg,
        if (lastSeenAnnouncementsAt != null)
          'lastSeenAnnouncementsAt':
              Timestamp.fromDate(lastSeenAnnouncementsAt!),
      };
}
