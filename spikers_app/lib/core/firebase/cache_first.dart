import 'package:cloud_firestore/cloud_firestore.dart';

/// Stale-while-revalidate for one-shot Firestore reads.
///
/// A plain `get()` waits for the server and only falls back to the on-device
/// cache once the SDK decides it is *offline* — on a slow (but connected)
/// network that means a spinner for the whole round trip even when the cache
/// already holds a perfectly good answer. Live `snapshots()` listeners don't
/// have this problem; this gives one-shot reads the same behavior.
///
/// [read] is called twice: first with `Source.cache` (served instantly from
/// disk, emitted only when [isUsable] accepts it — an empty cache result
/// usually means "never fetched", not "no data"), then with the default
/// source for the fresh value. If the server read fails after a cached value
/// was emitted, the stream just ends so the UI keeps showing the cached copy;
/// with nothing cached the error propagates as before.
Stream<T> cacheThenServer<T>(
  Future<T> Function(GetOptions options) read, {
  required bool Function(T value) isUsable,
}) async* {
  var servedFromCache = false;
  try {
    final cached = await read(const GetOptions(source: Source.cache));
    if (isUsable(cached)) {
      servedFromCache = true;
      yield cached;
    }
  } catch (_) {
    // Nothing cached (Source.cache throws for a missing document) — fall
    // through to the server read.
  }
  try {
    yield await read(const GetOptions());
  } catch (_) {
    if (!servedFromCache) rethrow;
  }
}
