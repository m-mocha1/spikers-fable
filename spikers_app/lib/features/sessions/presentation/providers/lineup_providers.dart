import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/lineup.dart';
import '../../domain/repositories/sessions_repository.dart';
import 'sessions_providers.dart';

/// Public profiles by uid for the line-up tokens, keyed by a comma-joined uid
/// string (family params need value equality). Uses the shared profile cache
/// so names/photos paint from the on-device copy first.
final lineupProfilesProvider = StreamProvider.autoDispose
    .family<Map<String, PublicProfile>, String>((ref, joinedUids) {
  final uids = joinedUids.split(',').where((u) => u.isNotEmpty).toList();
  if (uids.isEmpty) return Stream.value(const {});
  return ref.watch(sessionsRepositoryProvider).watchPublicProfilesCached(uids);
});

/// The session's shared line-up, keyed by session id. Live: coaches' edits
/// stream to every viewer. Edits apply locally first (instant drag feedback),
/// then save; a rejected save rolls back to the previous line-up.
final lineupProvider = AsyncNotifierProvider.autoDispose
    .family<LineupNotifier, Lineup, String>(LineupNotifier.new);

class LineupNotifier extends AutoDisposeFamilyAsyncNotifier<Lineup, String> {
  final _rng = Random();

  @override
  Future<Lineup> build(String sessionId) {
    final first = Completer<Lineup>();
    final sub = ref
        .watch(sessionsRepositoryProvider)
        .watchLineup(sessionId)
        .listen(
      (lineup) {
        if (first.isCompleted) {
          state = AsyncData(lineup);
        } else {
          first.complete(lineup);
        }
      },
      onError: (Object e, StackTrace st) {
        if (first.isCompleted) {
          state = AsyncError(e, st);
        } else {
          first.completeError(e, st);
        }
      },
    );
    ref.onDispose(sub.cancel);
    return first.future;
  }

  Future<void> move(String uid, LineupSlot to, List<String> attendeeIds) =>
      _apply(attendeeIds, (current) => current.move(uid, to));

  Future<void> shuffle(List<String> attendeeIds) =>
      _apply(attendeeIds, (_) => Lineup.shuffle(attendeeIds, _rng));

  Future<void> clear(List<String> attendeeIds) =>
      _apply(attendeeIds, (_) => Lineup.empty());

  /// Applies [edit] to the current line-up (minus anyone who left the
  /// session), shows it immediately, and saves it. A rejected save is not
  /// rolled back here: Firestore reverts its own optimistic write and the
  /// stream above delivers the corrected line-up, which — unlike a stale
  /// local snapshot — keeps any later edit that did succeed.
  Future<void> _apply(
      List<String> attendeeIds, Lineup Function(Lineup current) edit) async {
    final next =
        edit((state.value ?? Lineup.empty()).reconcile(attendeeIds));
    state = AsyncData(next);
    await ref.read(sessionsRepositoryProvider).saveLineup(
          arg,
          next,
          ref.read(currentUserProvider).value?.uid ?? '',
        );
  }
}
