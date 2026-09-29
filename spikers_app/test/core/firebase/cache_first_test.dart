import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spikers_app/core/firebase/cache_first.dart';

void main() {
  bool fromCache(GetOptions o) => o.source == Source.cache;

  test('emits the cached value first, then the server value', () async {
    final values = await cacheThenServer<List<int>>(
      (o) async => fromCache(o) ? [1] : [1, 2],
      isUsable: (v) => v.isNotEmpty,
    ).toList();
    expect(values, [
      [1],
      [1, 2],
    ]);
  });

  test('skips an unusable (empty) cache result', () async {
    final values = await cacheThenServer<List<int>>(
      (o) async => fromCache(o) ? <int>[] : [7],
      isUsable: (v) => v.isNotEmpty,
    ).toList();
    expect(values, [
      [7],
    ]);
  });

  test('a cache read that throws falls through to the server', () async {
    final values = await cacheThenServer<List<int>>(
      (o) async => fromCache(o) ? throw StateError('no cache') : [3],
      isUsable: (v) => v.isNotEmpty,
    ).toList();
    expect(values, [
      [3],
    ]);
  });

  test('a server failure after a cached value keeps the cached value',
      () async {
    final values = await cacheThenServer<List<int>>(
      (o) async => fromCache(o) ? [1] : throw StateError('offline'),
      isUsable: (v) => v.isNotEmpty,
    ).toList();
    expect(values, [
      [1],
    ]);
  });

  test('a server failure with nothing cached propagates', () async {
    final stream = cacheThenServer<List<int>>(
      (o) async => fromCache(o) ? <int>[] : throw StateError('offline'),
      isUsable: (v) => v.isNotEmpty,
    );
    await expectLater(stream.toList(), throwsStateError);
  });
}
