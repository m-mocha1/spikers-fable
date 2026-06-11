import 'package:cloud_firestore/cloud_firestore.dart';

class CoachSummary {
  final String uid;
  final String name;
  final String photoUrl;

  const CoachSummary({
    required this.uid,
    required this.name,
    required this.photoUrl,
  });

  factory CoachSummary.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return CoachSummary(
      uid: doc.id,
      name: (d['name'] ?? '') as String,
      photoUrl: (d['photoUrl'] ?? '') as String,
    );
  }
}
