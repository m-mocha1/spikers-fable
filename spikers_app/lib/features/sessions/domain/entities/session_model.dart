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

  /// Additional coaches marked as available/assigned for this session, on top
  /// of the owner [coachId]. Uids of accounts with role 'coach'.
  final List<String> coachIds;

  /// When non-empty, the session is a "custom" session visible only to these
  /// members (players), overriding the gender/age audience. See [isCustom].
  final List<String> memberIds;
  final List<String> attendeeIds;
  final List<String> attendedIds;
  final int waitlistSize;
  final List<String> waitlistIds;
  final bool notified;

  /// Whether a coach has explicitly taken attendance for this session (via the
  /// "confirm attendance" flow). Distinguishes "nobody was marked because the
  /// coach hasn't done it yet" from "the coach took attendance and nobody
  /// showed" — drives the post-session take-attendance prompt for coaches.
  final bool attendanceConfirmed;

  /// Admin "silent" session (created with notifications off). Persisted so the
  /// whole lifecycle stays quiet — cancelSession also skips its FCM fan-out when
  /// this is true. See the create-session admin toggle.
  final bool silent;
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
    this.coachIds = const [],
    this.memberIds = const [],
    required this.attendeeIds,
    this.attendedIds = const [],
    this.waitlistSize = 0,
    this.waitlistIds = const [],
    this.notified = false,
    this.attendanceConfirmed = false,
    this.silent = false,
    required this.createdAt,
    this.designIndex = 0,
  });

  /// A custom session is scoped to a hand-picked member list rather than the
  /// gender/age audience. Visible only to those members (and to coaches).
  bool get isCustom => memberIds.isNotEmpty;

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
      coachIds: List<String>.from(d['coachIds'] ?? []),
      memberIds: List<String>.from(d['memberIds'] ?? []),
      attendeeIds: List<String>.from(d['attendeeIds'] ?? []),
      attendedIds: List<String>.from(d['attendedIds'] ?? []),
      waitlistSize: (d['waitlistSize'] ?? 0) as int,
      waitlistIds: List<String>.from(d['waitlistIds'] ?? []),
      notified: d['notified'] ?? false,
      attendanceConfirmed: d['attendanceConfirmed'] ?? false,
      silent: d['silent'] ?? false,
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
        'coachIds': coachIds,
        'memberIds': memberIds,
        'attendeeIds': attendeeIds,
        'attendedIds': attendedIds,
        'waitlistSize': waitlistSize,
        'waitlistIds': waitlistIds,
        'notified': notified,
        'attendanceConfirmed': attendanceConfirmed,
        'silent': silent,
        'createdAt': Timestamp.fromDate(createdAt),
        'designIndex': designIndex,
      };
}
