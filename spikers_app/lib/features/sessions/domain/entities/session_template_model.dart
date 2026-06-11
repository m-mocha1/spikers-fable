import 'package:cloud_firestore/cloud_firestore.dart';

class SessionTemplate {
  final String id;
  final String title;
  final String location;
  final String gender;
  final int minAge;
  final int maxAge;
  final int maxPlayers;
  final int waitlistSize;
  final DateTime createdAt;

  const SessionTemplate({
    required this.id,
    required this.title,
    required this.location,
    required this.gender,
    required this.minAge,
    required this.maxAge,
    required this.maxPlayers,
    this.waitlistSize = 0,
    required this.createdAt,
  });

  factory SessionTemplate.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SessionTemplate(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      location: (d['location'] ?? '') as String,
      gender: (d['gender'] ?? 'mixed') as String,
      minAge: (d['minAge'] ?? 0) as int,
      maxAge: (d['maxAge'] ?? 99) as int,
      maxPlayers: (d['maxPlayers'] ?? 10) as int,
      waitlistSize: (d['waitlistSize'] ?? 0) as int,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'location': location,
        'gender': gender,
        'minAge': minAge,
        'maxAge': maxAge,
        'maxPlayers': maxPlayers,
        'waitlistSize': waitlistSize,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
