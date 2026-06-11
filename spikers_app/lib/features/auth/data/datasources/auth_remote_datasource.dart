import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:spikers_app/features/auth/domain/entities/user_model.dart';

/// Raw Firebase operations for the auth feature. No error mapping, no
/// session orchestration — that's the repository's job.
class AuthRemoteDataSource {
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  final FirebaseStorage storage;
  final FirebaseFunctions functions;

  AuthRemoteDataSource({
    required this.auth,
    required this.db,
    required this.storage,
    required this.functions,
  });

  Future<void> signIn(String email, String password) =>
      auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> createAccount(String email, String password) =>
      auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => auth.signOut();

  Stream<DocumentSnapshot<Map<String, dynamic>>> userDocStream(String uid) =>
      db.collection('users').doc(uid).snapshots();

  Future<void> createUserDoc(UserModel user, String? photoUrl) =>
      db.collection('users').doc(user.uid).set({
        ...user.toMap(),
        'photoUrl': ?photoUrl,
      });

  Future<String> uploadProfilePhoto(String uid, String filePath) async {
    final ref = storage.ref('profilePhotos/$uid.jpg');
    await ref.putFile(File(filePath));
    return ref.getDownloadURL();
  }

  Future<void> updateUserDoc(String uid, Map<String, dynamic> data) =>
      db.collection('users').doc(uid).update(data);

  Future<void> writeFcmToken(String uid, String token) =>
      db.collection('users').doc(uid).collection('private').doc('fcm').set(
        {
          'token': token,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

  /// Returns whether the backend accepted the coach key and promoted the
  /// caller. Throws on network/function errors.
  Future<bool> validateCoachKey(String key) async {
    final result =
        await functions.httpsCallable('validateCoachKey').call({'key': key});
    return (result.data?['valid'] ?? false) as bool;
  }
}
