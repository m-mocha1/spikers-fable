import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String id;
  final String title;
  final String location;
  final String gender;
  final int minAge;
  final int maxAge;
  final DateTime startTime;
  final DateTime endTime;
  final int maxPlayers;
  final String coachId;
  final List<String> attendeeIds;
  final List<String> attendedIds;
  final int waitlistSize;
  final List<String> waitlistIds;
  final bool notified;
  final DateTime createdAt;
  final int designIndex;

  const SessionModel({
    required this.id,
    required this.title,
    required this.location,
    required this.gender,
    required this.minAge,
    required this.maxAge,
    required this.startTime,
    required this.endTime,
    required this.maxPlayers,
    required this.coachId,
    required this.attendeeIds,
    this.attendedIds = const [],
    this.waitlistSize = 0,
    this.waitlistIds = const [],
    this.notified = false,
    required this.createdAt,
    this.designIndex = 0,
  });

  bool get isFull => attendeeIds.length >= maxPlayers;
  bool get isExpired => endTime.isBefore(DateTime.now());
  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  bool get isUpcoming => DateTime.now().isBefore(startTime);
  int get spotsLeft => maxPlayers - attendeeIds.length;
  bool isJoinedBy(String uid) => attendeeIds.contains(uid);

  bool get hasWaitlist => waitlistSize > 0;
  bool get isWaitlistFull => waitlistIds.length >= waitlistSize;
  int get waitlistSpotsLeft => waitlistSize - waitlistIds.length;
  bool isWaitlistedBy(String uid) => waitlistIds.contains(uid);

  factory SessionModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SessionModel(
      id: doc.id,
      title: d['title'] ?? '',
      location: d['location'] ?? '',
      gender: d['gender'] ?? 'mixed',
      minAge: (d['minAge'] ?? 0) as int,
      maxAge: (d['maxAge'] ?? 99) as int,
      startTime: (d['startTime'] as Timestamp).toDate(),
      endTime: (d['endTime'] as Timestamp).toDate(),
      maxPlayers: (d['maxPlayers'] ?? 10) as int,
      coachId: d['coachId'] ?? '',
      attendeeIds: List<String>.from(d['attendeeIds'] ?? []),
      attendedIds: List<String>.from(d['attendedIds'] ?? []),
      waitlistSize: (d['waitlistSize'] ?? 0) as int,
      waitlistIds: List<String>.from(d['waitlistIds'] ?? []),
      notified: d['notified'] ?? false,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      designIndex: ((d['designIndex'] ?? 0) as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'location': location,
        'gender': gender,
        'minAge': minAge,
        'maxAge': maxAge,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'maxPlayers': maxPlayers,
        'coachId': coachId,
        'attendeeIds': attendeeIds,
        'attendedIds': attendedIds,
        'waitlistSize': waitlistSize,
        'waitlistIds': waitlistIds,
        'notified': notified,
        'createdAt': Timestamp.fromDate(createdAt),
        'designIndex': designIndex,
      };
}
