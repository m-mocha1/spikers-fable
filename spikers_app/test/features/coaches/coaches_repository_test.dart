import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spikers_app/core/errors/account_action_exception.dart';
import 'package:spikers_app/features/coaches/data/datasources/coaches_remote_datasource.dart';
import 'package:spikers_app/features/coaches/data/repositories/coaches_repository_impl.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _FakeResult extends Fake implements HttpsCallableResult {
  @override
  final dynamic data;
  _FakeResult(this.data);
}

void main() {
  late _MockFunctions fns;
  late CoachesRepositoryImpl repo;

  setUp(() {
    fns = _MockFunctions();
    repo = CoachesRepositoryImpl(
        CoachesRemoteDataSource(FakeFirebaseFirestore(), fns));
  });

  group('deleteCoach', () {
    test('calls adminDeleteUser with the target uid', () async {
      final callable = _MockCallable();
      when(() => callable.call<dynamic>(any()))
          .thenAnswer((_) async => _FakeResult({'success': true}));
      when(() => fns.httpsCallable('adminDeleteUser')).thenReturn(callable);

      await repo.deleteCoach('c1');

      verify(() => callable.call<dynamic>({'userId': 'c1'})).called(1);
    });

    test('wraps FirebaseFunctionsException into AccountActionException',
        () async {
      final callable = _MockCallable();
      when(() => callable.call<dynamic>(any())).thenThrow(
          FirebaseFunctionsException(
              message: 'Admin accounts cannot be deleted',
              code: 'failed-precondition'));
      when(() => fns.httpsCallable('adminDeleteUser')).thenReturn(callable);

      await expectLater(
        repo.deleteCoach('admin1'),
        throwsA(isA<AccountActionException>()
            .having((e) => e.code, 'code', 'failed-precondition')),
      );
    });
  });
}
