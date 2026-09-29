import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spikers_app/features/auth/domain/entities/user_model.dart';
import 'package:spikers_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:spikers_app/features/auth/presentation/providers/auth_providers.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

UserModel _user({String name = 'U', String gender = 'male'}) => UserModel(
      uid: 'u1',
      name: name,
      gender: gender,
      dateOfBirth: DateTime(2000),
      role: 'player',
      createdAt: DateTime(2026),
    );

void main() {
  late StreamController<UserModel?> users;
  late ProviderContainer container;
  late List<UserModel?> notified;

  setUp(() async {
    users = StreamController<UserModel?>.broadcast();
    final repo = _MockAuthRepo();
    when(() => repo.watchCurrentUser()).thenAnswer((_) => users.stream);
    when(() => repo.isEmailVerified).thenReturn(true);
    container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)]);
    notified = [];
    container.listen(queryViewerProvider, (_, next) => notified.add(next));
    users.add(_user());
    await pumpEventQueue();
    notified.clear();
  });

  tearDown(() {
    container.dispose();
    users.close();
  });

  // Slow-network regression: every user-doc write used to rebuild the query
  // providers, tearing down their listeners and re-downloading the lists.
  test('does not re-notify when an unrelated user field changes', () async {
    users.add(_user(name: 'Renamed'));
    await pumpEventQueue();
    expect(notified, isEmpty);
  });

  test('re-notifies when a query-scoping field changes', () async {
    users.add(_user(gender: 'female'));
    await pumpEventQueue();
    expect(notified.single?.gender, 'female');
  });

  test('re-notifies on sign-out', () async {
    users.add(null);
    await pumpEventQueue();
    expect(notified, [null]);
  });
}
