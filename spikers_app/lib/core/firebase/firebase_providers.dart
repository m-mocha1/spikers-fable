import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase SDK entry points as providers so repositories never touch the
/// singletons directly — tests override these with fakes
/// (fake_cloud_firestore, firebase_auth_mocks).

const kFunctionsRegion = 'europe-west1';

/// Options for every callable. The SDK default timeout is 60s, which on a bad
/// network leaves a spinner up for a minute before any feedback. A client
/// timeout does NOT cancel the server call, so it stays generous enough not
/// to report failures for calls that were merely slow; the callables are
/// idempotent, so retrying after a timeout is safe.
final kCallableOptions =
    HttpsCallableOptions(timeout: const Duration(seconds: 30));

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final firebaseFunctionsProvider = Provider<FirebaseFunctions>(
    (ref) => FirebaseFunctions.instanceFor(region: kFunctionsRegion));

final firebaseStorageProvider =
    Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

final firebaseMessagingProvider =
    Provider<FirebaseMessaging>((ref) => FirebaseMessaging.instance);
