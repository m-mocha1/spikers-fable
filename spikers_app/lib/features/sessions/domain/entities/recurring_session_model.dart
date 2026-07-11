import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RecurringSessionModel {
  final String id;
  final String coachId;
  final String title;
  final String location;
  final String gender;
  final int minAge;
  final int maxAge;
  final int maxPlayers;
  final int waitlistSize;

  /// Additional coaches marked as available/assigned, copied onto each session
  /// this recurring template materializes. Uids of accounts with role 'coach'.
  final List<String> coachIds;

  /// When non-empty, materialized sessions are custom (members-only): visible
  /// to these member uids (and coaches), overriding the gender/age audience.
  final List<String> memberIds;
  final List<int> recurrenceDays;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final bool enabled;
  final String? lastCreatedDate;
  final DateTime createdAt;

  const RecurringSessionModel({
    required this.id,
    required this.coachId,
    required this.title,
    required this.location,
    required this.gender,
    required this.minAge,
    required this.maxAge,
    required this.maxPlayers,
    this.waitlistSize = 0,
    this.coachIds = const [],
    this.memberIds = const [],
    required this.recurrenceDays,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.enabled = true,
    this.lastCreatedDate,
    required this.createdAt,
  });

  factory RecurringSessionModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    if (createdAt == null) {
      debugPrint(
          'RecurringSessionModel: missing createdAt on ${doc.id}, falling back to now()');
    }
    return RecurringSessionModel(
      id: doc.id,
      coachId: (d['coachId'] ?? '') as String,
      title: (d['title'] ?? '') as String,
      location: (d['location'] ?? '') as String,
      gender: (d['gender'] ?? 'mixed') as String,
      minAge: (d['minAge'] ?? 16) as int,
      maxAge: (d['maxAge'] ?? 40) as int,
      maxPlayers: (d['maxPlayers'] ?? 12) as int,
      waitlistSize: (d['waitlistSize'] ?? 0) as int,
      coachIds: List<String>.from(d['coachIds'] ?? []),
      memberIds: List<String>.from(d['memberIds'] ?? []),
      recurrenceDays: List<int>.from(d['recurrenceDays'] ?? []),
      startHour: (d['startHour'] ?? 18) as int,
      startMinute: (d['startMinute'] ?? 0) as int,
      endHour: (d['endHour'] ?? 20) as int,
      endMinute: (d['endMinute'] ?? 0) as int,
      enabled: (d['enabled'] ?? true) as bool,
      lastCreatedDate:
          d['lastCreatedDate'] is String ? d['lastCreatedDate'] as String : null,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'coachId': coachId,
        'title': title,
        'location': location,
        'gender': gender,
        'minAge': minAge,
        'maxAge': maxAge,
        'maxPlayers': maxPlayers,
        'waitlistSize': waitlistSize,
        'coachIds': coachIds,
        'memberIds': memberIds,
        'recurrenceDays': recurrenceDays,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
        'enabled': enabled,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
