import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/announcement.dart';

class AnnouncementsRemoteDataSource {
  final FirebaseFirestore _db;

  AnnouncementsRemoteDataSource(this._db);

  Stream<List<AnnouncementModel>> watchAll() => _db
      .collection('announcements')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(AnnouncementModel.fromDoc).toList());

  Future<void> markRead(String uid) =>
      _db.collection('users').doc(uid).update({
        'lastSeenAnnouncementsAt': FieldValue.serverTimestamp(),
      });

  Future<void> create({
    required String title,
    required String body,
    required String authorId,
    required String authorName,
    required String audience,
  }) =>
      _db.collection('announcements').add({
        'title': title,
        'body': body,
        'authorId': authorId,
        'authorName': authorName,
        'audience': audience,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> edit({
    required String id,
    required String title,
    required String body,
    required String audience,
  }) =>
      _db.collection('announcements').doc(id).update({
        'title': title,
        'body': body,
        'audience': audience,
      });

  Future<void> delete(String id) =>
      _db.collection('announcements').doc(id).delete();
}
