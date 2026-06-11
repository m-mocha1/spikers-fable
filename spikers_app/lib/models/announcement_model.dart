import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AnnouncementModel {
  final String id;
  final String title;
  final String body;
  final String authorId;
  final String authorName;
  final DateTime createdAt;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
  });

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
    );
  }
}
