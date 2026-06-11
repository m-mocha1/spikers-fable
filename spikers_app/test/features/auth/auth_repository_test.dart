import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spikers_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:spikers_app/features/auth/data/datasources/credential_store.dart';
import 'package:spikers_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:spikers_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';

class _MockRemote extends Mock implements AuthRemoteDataSource {}

class _MemoryCredentialStore implements CredentialStore {
  StoredCredentials? stored;
  @override
  Future<StoredCredentials?> read() async => stored;
  @override
  Future<void> save(String email, String password) async =>
      stored = StoredCredentials(email, password);
  @override
  Future<void> clear() async => stored = null;
}

void main() {
  late _MockRemote remote;
  late _MemoryCredentialStore credentials;
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore db;

  AuthRepositoryImpl makeRepo() => AuthRepositoryImpl(
        remote: remote,
        credentials: credentials,
        messaging: null,
      );

  setUp(() {
    remote = _MockRemote();
    credentials = _MemoryCredentialStore();
    db = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    when(() => remote.auth).thenReturn(mockAuth);
    when(() => remote.userDocStream(any())).thenAnswer(
        (inv) => db.collection('users').doc(inv.positionalArguments[0] as String).snapshots());
  });

  Future<void> seedUserDoc(String uid) => db.collection('users').doc(uid).set({
        'name': 'Test',
        'gender': 'male',
        'dateOfBirth': Timestamp.fromDate(DateTime(2000)),
        'role': 'player',
        'createdAt': Timestamp.fromDate(DateTime(2026)),
        'verifiedAt': null,
      });

  group('signIn', () {
    test('saves credentials on success', () async {
      final repo = makeRepo();
      await repo.init();
      when(() => remote.signIn(any(), any())).thenAnswer((_) async {
        await mockAuth.signInWithEmailAndPassword(
            email: 'a@b.c', password: 'secret');
      });

      await repo.signIn('  a@b.c ', 'secret');

      expect(credentials.stored?.email, 'a@b.c');
      expect(credentials.stored?.password, 'secret');
    });

    test('maps FirebaseAuthException to AuthException and keeps store empty',
        () async {
      final repo = makeRepo();
      await repo.init();
      when(() => remote.signIn(any(), any()))
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));

      await expectLater(
        repo.signIn('a@b.c', 'bad'),
        throwsA(isA<AuthException>()
            .having((e) => e.code, 'code', 'wrong-password')),
      );
      expect(credentials.stored, isNull);
    });
  });

  group('session restore', () {
    test('init signs in from stored credentials and emits the user doc',
        () async {
      mockAuth = MockFirebaseAuth(
          mockUser: MockUser(uid: 'u1', email: 'a@b.c'));
      when(() => remote.auth).thenReturn(mockAuth);
      credentials.stored = const StoredCredentials('a@b.c', 'secret');
      when(() => remote.signIn(any(), any())).thenAnswer((_) async {
        await mockAuth.signInWithEmailAndPassword(
            email: 'a@b.c', password: 'secret');
      });
      await seedUserDoc('u1');

      final repo = makeRepo();
      await repo.init();
      await repo.ready;

      final user = await repo.watchCurrentUser().first;
      expect(user, isA<UserModel>());
      expect(user!.name, 'Test');
      verify(() => remote.signIn('a@b.c', 'secret')).called(1);
    });

    test('failed restore clears stored credentials', () async {
      credentials.stored = const StoredCredentials('a@b.c', 'stale');
      when(() => remote.signIn(any(), any()))
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));

      final repo = makeRepo();
      await repo.init();
      await repo.ready;

      expect(credentials.stored, isNull);
      expect(repo.currentUserNow, isNull);
    });
  });

  group('signOut', () {
    test('clears credentials and emits null', () async {
      credentials.stored = const StoredCredentials('a@b.c', 'secret');
      when(() => remote.signOut()).thenAnswer((_) async {});
      final repo = makeRepo();
      await repo.init();

      await repo.signOut();

      expect(credentials.stored, isNull);
      expect(repo.currentUserNow, isNull);
    });
  });
}
