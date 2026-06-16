import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AnnouncementModel {
  final String id;
  final String title;
  final String body;
  final String authorId;
  final String authorName;
  final DateTime createdAt;

  /// Target audience: 'all' (everyone), 'male' or 'female'. Legacy docs with
  /// no field default to 'all', so they stay visible to everyone.
  final String audience;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.audience = 'all',
  });

  /// Whether this announcement should be shown to a given user. Coaches and
  /// admins always see every announcement (so they can manage them); players
  /// see 'all' plus those targeting their own gender. A player who hasn't
  /// provided a gender ([gender] == null) only sees 'all' announcements.
  bool visibleTo({required bool isCoach, required String? gender}) =>
      isCoach || audience == 'all' || audience == gender;

  factory AnnouncementModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    if (createdAt == null) {
      debugPrint(
          'AnnouncementModel: missing createdAt on ${doc.id}, falling back to now()');
    }
    return AnnouncementModel(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      body: (d['body'] ?? '') as String,
      authorId: (d['authorId'] ?? '') as String,
      authorName: (d['authorName'] ?? '') as String,
      createdAt: createdAt ?? DateTime.now(),
      audience: (d['audience'] ?? 'all') as String,
    );
  }
}
